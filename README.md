ruby-flickr-uploader
====================

Flickr uploader is a ruby script to automatically upload and tag photos to Flickr.

It is designed to process many pictures and albums (sets), with a workflow that makes it easy to troubleshoot or see status just by looking at the filesystem. 

## Prerequisites

* Ruby
* flickraw: https://github.com/hanklords/flickraw
* Yaml

## Tested on

* Mac OS X 10.7.3
* Mac OS X 10.8
* Ruby: ruby 1.9.1p431 (2011-02-18 revision 30908) [i386-darwin10.6.0]
* Ruby: ruby 1.8.7


## Getting started

### Flickr API Key

To run the script, you'll need an API key from your flickr account.
You can find and create your API keys associated with your account at http://www.flickr.com/services/api/keys/

When done, you'll need your *key* and *secret* to run the script.

### Configure Flickr Uploader

Copy *config.yml-dist* to *config.yml* and add your key (api_key parameter) and secret (shared_secret) parameter from flickr

Configuration file reference:
* api_key: flickr API key
* shared_secret: flickr shared secret
* access_token: flickr access token
* access_secret: flickr access secret 
* upload_path1_todo: where images go before starting upload
* upload_path2_inprogress: once a single image is uploaded, it is moved to here
* upload_path3_done: once all images from an album in path1 are uploaded, album is removed from path1 and path2 album is moved here
* allowed_ext: filter files to upload by extension

### Authenticate the script with Flickr

Run `ruby authenticate.rb` to get your *access_token* and *access_secret*


    $ ruby authenticate.rb
    Open this url in your process to complete the authication process : http://www.flickr.com/services/oauth/authorize?oauth_token=AAAAAAAAAAAAAAAAA-bbbbbbbbbbbb&perms=delete
    Copy here the number given when you complete the process.
    123-456-789
    You are now authenticated as Campeur with token CCCCCCCCCCCCCCCCC-ddddddddddddddddd and secret eeeeeeeeeeeeeeee
    $ _


You can now add token (access_token) and (access_secret) secret to your *config.yml* 

## Workflow

The script's workflow, or process, is broken up to 3 steps, with 2 goals in mind.
The first goal is to make it fast and easy to get pictures onto flickr.
The second goal is to make it easy to troubleshoot if something goes wrong.

The script's 3 steps correspond to the 3 paths in the filesystem, so you can see status just by viewing files and directories.

1. Script reads albums in *upload_path1_todo*, and begins upload.

2. As each picture is successfully uploaded, it is moved to *upload_path2_inprogress*

3. Once all images from an album in path1 are uploaded, album is removed from path1, and the path2 album 
(which at this point is same as album was in path1 at the start) is moved to *upload_path3_done*

### Troubleshooting

If internet connection does go out, or there is an issue with the flickr api, the above steps help you by 
making it easy to compare the script thinks has happened with what you see on flickr.
Specifically you can view which albums are done uploading, which are still in progress (and what images are left), and which have not even started.
On flickr you can search using tags to see which photos were actually uploaded successfully.

### Fetch your sets

This script will not create sets if they do not exist. You can create your set using flickr api.

If a set DOES exist, the photo will be added to it.  You should get names of photosets before uploading.

Due to Flickr API limitation, I'm using a temporary yaml (*photosets.yml*) file to store your flickr sets. I use this file to query a set by its name.

    $ ruby get_photosets.rb 
    You are now authenticated as John
    photosets.yml saved.

### Upload process

The script works with a hierarchy of one or two folder levels.  For both levels, photos are given a tag that is the album name, 
and a tag 'uploaded_by_rubyflickr'.  The uploaded tag should make it easy to find and verify on flickr.com that the upload worked (this tag can be removed).
If there are two folder levels, the folder under the album is used to give additional tags to photos within it.

    * APP_CONFIG['upload_path1_todo']
      - Album1
        - IMG_0001.jpg
      - Album2
        - IMG_0002.jpg
        - tag1
          - IMG_0003.jpg
      - Album4
        - tag2,tag3
          - IMG_0004.jpg
      ...


In this example, the script will upload:

* IMG_0001.jpg in album *Album1* with tags *Album1* and uploaded_by_rubyflickr

* IMG_0002.jpg in album *Album2* with tags *Album2* and uploaded_by_rubyflickr

* IMG_0003.jpg in album *Album2* with tags *Album2*, *tag1*, and uploaded_by_rubyflickr

* IMG_0004.jpg in album *Album4* with tags *Album4*, *tag2*, *tag3*, and uploaded_by_rubyflickr


### Example

    $ ruby get_photosets.rb 
    You are now authenticated as chadn
    photosets.yml saved.

    $ ruby upload.rb 
	Processing /Users/chadn/Pictures/chad-flickr/upload-1-todo 2013-02-18T09:53:02
	You are now authenticated as chadn
	         Uploading album 'Thanksgiving ATL 2012' to flickr photoset 72157632675155088
	- will upload 'img_0231.jpg' in album 'Thanksgiving 2012' with tags: Thanksgiving 2012,uploaded_by_rubyflickr
	         upload done. moved to /Users/chadn/Pictures/chad-flickr/upload-2-inprogress/Thanksgiving 2012/img_0231.jpg
	         Adding pic to album 'Thanksgiving 2012' photoset 72157632675155088
	...
	Done with album: /Users/chadn/Pictures/chad-flickr/upload-1-todo/Thanksgiving ATL 2012

## TODO

* add a Gemfile
* add support for movie files
* add pictures http://github.com/CharlyBr/ruby-flickr-uploader/raw/master/img/foo.png

## Licence

ruby-flickr-uploader is released under the MIT license:

* [http://www.opensource.org/licenses/MIT](http://www.opensource.org/licenses/MIT)


[![githalytics.com alpha](https://cruel-carlota.pagodabox.com/6ee9cfa9b21f99f3ffe633b7836ebdfd "githalytics.com")](http://githalytics.com/chadn/ruby-flickr-uploader)
