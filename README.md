[![Build](https://github.com/wibosco/PausableDownloads-Example/actions/workflows/swift.yml/badge.svg)](https://github.com/wibosco/PausableDownloads-Example/actions/workflows/swift.yml)
<a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-5-orange.svg?style=flat" alt="Swift 5" /></a>
[![License](http://img.shields.io/badge/License-MIT-green.svg?style=flat)](https://github.com/wibosco/PausableDownloads-Example/blob/main/LICENSE)

# PausableDownloads-Example
An example project showing how to pause and resume downloads as shown in this post - [https://williamboles.com/not-all-downloads-are-born-equal/](https://williamboles.com/dont-throw-anything-away-with-pausable-downloads/)

In order to run this project, you will need to register with [TheCatAPI](https://thecatapi.com/) to get an API key to access TheCatAPI's API (which the project uses to get its example content). Once you have your key, add an `xcconfig` file called `Secrets` to the top directory with your key as the value of `CAT_API_KEY` and the project should now run.

## Seeing a download resume

The app is a gallery of cat images that you can swipe through. The downloading of each image starts when you land on it. Swiping away from an image that hasn't finished downloading pauses it; swiping back resumes that download from where it left off rather than starting it again.

If you have a modestly fast internet connection, you will probably struggle to pause a download before it finishes. Use [`Network Link Conditioner`](https://developer.apple.com/download/all/?q=Additional%20Tools) to throttle your connection.
