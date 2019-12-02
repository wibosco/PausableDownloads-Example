[![Build Status](https://travis-ci.org/wibosco/DownloadStack-Example.svg)](https://travis-ci.org/wibosco/DownloadStack-Example)
<a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-4.0-orange.svg?style=flat" alt="Swift" /></a>
<a href="https://twitter.com/wibosco"><img src="https://img.shields.io/badge/twitter-@wibosco-blue.svg?style=flat" alt="Twitter: @wibosco" /></a>

# DownloadStack-Example
A example project about treating download requests differently depending on how important they are to your app's UX, http://williamboles.me/not-all-downloads-are-born-equal/

In order to run this project, you will need to register with [Imgur](https://api.imgur.com/oauth2/addclient) to get a `client-id` token to access Imgur's API (which the project uses to get its example content). Once you have your `client-id`, add it to the project as the value of the `clientID` property in the `RequestConfig` class and the project should now run. If you have any trouble getting the project to run, please create an issue or get in touch with me on Twitter at [wibosco](https://twitter.com/wibosco).
