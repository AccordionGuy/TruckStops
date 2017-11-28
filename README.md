# TruckStops

I could *tell* you what this app does, but I can do even better — I can *show* you:

[!["Truck Stops" demo video](https://img.youtube.com/vi/6tHGYhKCx7o/0.jpg)](https://www.youtube.com/watch?v= 6tHGYhKCx7o)

## Table of contents

* [The story behind the app](The story behind the app)
* [Installation](installation)
* [Usage](usage)
* [License](license)

## The story behind the app

![Ben Affleck in the "job interview" scene from "Good Will Hunting".](http://www.globalnerdy.com/wordpress/wp-content/uploads/2013/11/job-interview.jpg)

We were ninety minutes into a one-hour job interview when the CTO said “We like your *breadth* of experience. Now we’d like to test your *depth*. If we gave you a quick programming assignment, which would you prefer — writing an iOS app, or an Android app? You should go with the one you’re stronger in.”

I’m a much stronger iOS programmer than an Android one. The smart move would’ve been to answer “iOS,” and be done with it.

Instead, I replied “Yes, but you want a guy who can lead a team of both iOS and Android developers. **You really should give me *both*.**”

The CTO raised an eyebrow, gave me a look, made a note on his pad, and said “Hmmm...I think I will.”

This is either a “total baller move” (to borrow a turn of phrase the kids are using these day), or the end of that job prospect. **But for the job that they’re trying to fill, taking on that challenge was the right thing to do.**

And hey, sometimes you have to **be like Han.**

!["Be Like Han" inspirational poster](http://www.globalnerdy.com/wordpress/wp-content/uploads/2017/11/be-like-han.jpg)

This app is a feature of the full-fledged trucker app made by the company with whom I was interviewing. Since the app predates Swift, it was written in Objective-C and as far as I know, it continues to be maintained in that language. As a result, one of the requirements for the test was that app I made had to be written in Objective-C.

It had been a couple of years since I’d touched C or Objective-C, but after bumping my head once or twice against C-isms (“Oh yeah, pointers”), I got into a groove and a few days later, I had an app that I could show them.

I sent them the iOS app. “Tell me what you think while I work on the Android version.”

And that’s the last I heard from them. Follow-up emails were met with silence. After the 6th email (“If you have any questions or comments about the app, please feel free to contact me”), it became apparent that this was a dead end, and it wouldn’t be worth my while to continue working on the Android version. Perhaps I’ll work on it as a way to sharpen my Kotlin skills.


## Installation

This is an Xcode 9 project (it was written in Xcode 8, but ported up).

It uses Cocoapods, which means that you should open **Truck Stops.xcworkspace** to open the project instead of **Truck Stops.xcodeproj**. I used CocoaPods to bring in the [Unirest Objective-C library](http://unirest.io/objective-c.html) to make HTTP requests to the server with the truck stop data.

### The project is intentionally missing a file
The project will not run as it is in this repository, It’s missing the file **SecureConstants.m**, which defines the values for the constants `API_URL_STRING` and `BASIC_AUTH_STRING`. These values are required to access the server with the truck stop data, and they’re confidential.


## Usage

Once installed on your iPhone or iPad, it runs pretty much like the video above, but without [the song *Convoy*](https://www.youtube.com/watch?v=EnJEeHND_lQ) playing in the background.

(If you’re young enough not to know about the movie *Convoy*, [here’s a summary.](https://en.wikipedia.org/wiki/Convoy_(1978_film)))


## License
This code is released under the [MIT license.](https://opensource.org/licenses/MIT) Simply put, you're free to use this in your own projects, both personal and commercial, as long as you include the copyright notice below. It would be nice if you mentioned my name somewhere in your documentation or credits.
