# soundgasm

Provides a basic read-only API for soundgasm.net in nim.

## Documentation

There are several properties that can be accessed, which are grouped into two categories:

- Type-1 Properties: `title`, `description`, `uploader`, `audioURL`
- Type-2 Properties: `playCount`

This API module works by downloading and parsing the relevant pages' HTML, and the Type-2 properties are ones which cannot be determined by reading a single page:
- play count is only visible on the uploader's public page

All of these properties can be accessed via their respective `getX` proc:

```nim
import soundgasm

const url = "https://soundgasm.net/u/.../..."

# Type-1 Properties
let title: string = getTitle(url)
let description: string = getDescription(url)
let uploader: Uploader = getUploader(url)
let audioURL: string = getAudioURL(url)

# Type-2 Properties
let playCount: int = getPlayCount(url)
```

However, each `getX` call incurs a network call, as they each make a request to the server before parsing out what they're looking for. When multiple properties are needed, it is generally preferred to use an `AudioData` object, which makes one network call and parses out all of the Type-1 properties:

```nim
let data: AudioData = get(url)

# Type-1 Properties
let title: string = data.title
let description: string = data.description
let uploader: Uploader = data.uploader
let audioURL: string = data.audioURL
```

The Type-2 properties can also be computed separately with the `AudioData` object:

```nim
let playCount: int = data.getPlayCount()
```

Note that `AudioData.getPlayCount()` does actually insert the value into the object, making subsequent calls use the cached value. This can be disabled (and a fresh call can be made) by passing `useCache=false`:

```nim
let freshPlayCount: int = data.getPlayCount(useCache=false)
```

With `Uploader` objects:

```nim
# these two are equivalent
let uploader: Uploader = Uploader(name: "...")
let uploader: Uploader = getUploader(name="...")

# name is the only public attribute
let name: string = uploader.name

# we can loop through their uploads
for audioData in uploader.audios():
  ...
```

Note that `audios(uploader: Uploader)` has two important characteristics, as a result of the fact that we're looking at the uploader's page:

- these `AudioData` objects actually already have updated `playCount` values
- `audioURL` is an expensive property as it requires polling and parsing the actual post's page. To avoid this, pass `withAudioURL=false`.

The following methods are also available:

```nim
let totalUploads: int = uploader.totalUploads()
let totalPlays: int = uploader.totalPlays()
```