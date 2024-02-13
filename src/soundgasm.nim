import std/[httpclient, htmlparser, re, strformat, strutils, xmltree]
import nimquery
import options

type
  AudioData* = object
    title*: string
    description*: string
    uploader*: Uploader
    audioURL*: string
    playCount: var Option[int]
    postURL: string

  Uploader* = object
    name*: string


proc getAudioURL*(url: string): string

proc getContent*(url: string): string =
  ## get the HTML content from the given URL
  let client = newHttpClient()
  try:
    return client.getContent(url)
  finally:
    client.close()


proc getBody(content: string): XmlNode =
  ## Parse the HTML content and navigate to the <body> tag.
  let root = parseHtml(content)
  return root.child("html").child("body")


proc getUploader*(name: string): Uploader =
  ## Get the uploader with the given name.
  return Uploader(name: name)


proc url*(uploader: Uploader): string =
  ## Return the url for the given uploader.
  return fmt"https://soundgasm.net/u/{uploader.name}"


proc parseSoundDetails(node: XmlNode, uploaderName: string, withAudioURL: bool = true): AudioData =
  ## Parse the <div class="sound-details"> node
  ## <div class="sound-details">
  ##    <a href="LINK-TO-PAGE">AUDIO TITLE</a>
  ##    <span class="soundDescription">DESCRIPTION</span>
  ##    <span class="playCount">Play Count: #</span>
  ## </div>
  
  let a = node.querySelector("a")
  let url = a.attr("href")
  let title = a.innerText()

  let description = node.querySelector("span.soundDescription").innerText()
  
  let playCountText = node.querySelector("span.playCount").innerText().replace(re"Play Count:\s+", "")
  var playCount = playCountText.parseInt()

  let audioURL = if withAudioURL: getAudioURL(url) else: ""

  return AudioData(
    title: title,
    description: description,
    uploader: getUploader(uploaderName),
    playCount: some(playCount),  # since we're on the uploader page, we can just set this value
    audioURL: audioURL,
    postURL: url
  )


iterator audios*(uploader: Uploader, withAudioURL: bool = true): AudioData =
  ## Iterate over the audios for the given uploader
  var content = getContent(uploader.url())
  content = content.replace(re"</br>", "")
  let html = parseHtml(content)

  for node in html.querySelectorAll("div.sound-details"):
    yield parseSoundDetails(node, uploader.name, withAudioUrl)


proc extractTitle(body: XmlNode): string =
  ## extract the title from the given body node.
  ## At present, this is in a <div class="jp-title"> node
  let element = body.querySelector("div.jp-title")
  return element.innerText()


proc extractDescription(body: XmlNode): string =
  ## extract the description from the given body node.
  ## At present, this is in the <p> child of a <div class="jp-description"> node.
  let element = body.querySelector("div.jp-description").child("p")
  return element.innerText()

proc extractUploaderName(body: XmlNode): string =
  ## extract the uploader from the given body node.
  ## At present, this is in the <a> child of the first <div> node.
  let element = body.child("div").child("a")
  return element.innerText()


proc extractAudioURL(content: string): string =
  ## extract the audio URL from the given html.
  ## At present, this is present within a <script> tag via a setMedia callback:
  ## $(this).jPlayer("setMedia", {
  ##  m4a: "https://media.soundgasm.net/sounds/filename.m4a"
  ## });
  let matches = content.findAll(re"m4a: ""(.*?)""")
  return matches[0][6..^2]  # [6..^2] strips off the leading 'm4a: "' and the trailing quote mark


proc get*(url: string): AudioData =
  ## Parse the given url and return an AudioData object.
  let content = getContent(url)
  let body = getBody(content)

  return AudioData(
    title: extractTitle(body),
    description: extractDescription(body),
    uploader: getUploader(extractUploaderName(body)),
    audioURL: extractAudioURL(content),
    postURL: url,
    playCount: none(int)
  )
  

proc getTitle*(url: string): string =
  ## Get the title of the audio referenced by the given url.
  let body = getBody(getContent(url))
  return extractTitle(body)


proc getDescription*(url: string): string =
  ## Get the description of the audio referenced by the given url.
  let body = getBody(getContent(url))
  return extractDescription(body)


proc getUploaderName*(url: string): string =
  ## Get the uploader of the audio referenced by the given url.
  let body = getBody(getContent(url))
  return extractUploaderName(body)


proc getAudioURL*(url: string): string =
  ## Get the direct audio URL for the audio referenced in the given url.
  let content = getContent(url)
  return extractAudioURL(content)


proc getPlayCount*(data: AudioData, useCache: bool = true): int =
  ## Get the number of plays for the audio.
  if data.playCount.isNone() or not useCache:
    for audio in data.uploader.audios(withAudioURL=false):
      if audio.postURL == data.postURL:
        data.playCount = audio.playCount
        break
  
  return data.playCount.get()


proc getPlayCount*(url: string): int =
  ## Get the number of plays for the audio referenced in the given url.
  let uploader = getUploader(name=getUploaderName(url))
  for audio in uploader.audios(withAudioURL=false):
    if audio.postURL == url:
      return audio.playCount.get()


proc totalUploads*(uploader: Uploader): int =
  ## Get the number of uploads made by this uploader.
  var i = 0
  for _ in uploader.audios(withAudioURL=false):
    i.inc()

  return i


proc totalPlays*(uploader: Uploader): int =
  ## Get the number of plays across all this uploader's audios.
  var i = 0
  for audio in uploader.audios(withAudioURL=false):
    i.inc(audio.playCount.get(0))
  
  return i