#!/usr/bin/env ruby
# encoding: utf-8
$LOAD_PATH << './'


#begin
#  found_gem = Gem::Specification.find_by_name('flickraw')
#rescue Gem::LoadError
#  puts "Could not find gem 'flickraw', try 'bundle install'"
#  exit
#end

require 'rubygems'
require 'FileUtils'
require 'flickraw'
require 'Photosets'

##
## Upload script
##

# https://github.com/hanklords/flickraw
# http://www.flickr.com/services/api/
# http://www.flickr.com/services/api/upload.api.html

APP_CONFIG = YAML.load_file("config.yml")['defaults']
$all_sets = Photosets.new
$noUpload = false  # if true, don't actually upload to flickr - used for testing.

FlickRaw.api_key = APP_CONFIG['api_key']
FlickRaw.shared_secret = APP_CONFIG['shared_secret']
flickr.access_token = APP_CONFIG['access_token']
flickr.access_secret = APP_CONFIG['access_secret']


def init
  if not validateDir APP_CONFIG['upload_path1_todo'], false
    puts "Your config upload_path1_todo doesn't exist."
    exit
  end
  if APP_CONFIG['upload_path1_todo'].empty? 
    puts "Your config upload_path1_todo is empty."
    exit
  end
  startTime = Time.now   #=> 2007-11-17 15:18:03 +0900
  puts "Processing #{APP_CONFIG['upload_path1_todo']} %s" % startTime.strftime("%FT%T")
  
  login = flickr.test.login
  puts "You are now authenticated as #{login.username}"
  
  Dir.glob("#{APP_CONFIG['upload_path1_todo']}/*").each do |album|
    next if album[0] == '.'
    album_filename = File.basename album
    #puts "album: #{album}"
    #puts "album filename: #{album_filename}"

    if not validateDir "#{APP_CONFIG['upload_path2_inprogress']}/#{album_filename}", true
      puts "Could not write to your config upload_path2_inprogress: " + APP_CONFIG['upload_path2_inprogress']
      exit
    end

    if not validateDir "#{APP_CONFIG['upload_path3_done']}/#{album_filename}", true
      puts "Could not write to your config upload_path3_done: " + APP_CONFIG['upload_path3_done']
      exit
    end

    # Check if destination album exists
    photoset = $all_sets.get_set_by_title(album_filename)
    if photoset == false
      puts "Uploading local album '#{album_filename}' as tagged pictures, no photoset found"
    else
      puts "Uploading local album '#{album_filename}' to flickr photoset #{photoset['id']}"
    end

    # Go through each album and process pictures
    #
    Dir.glob("#{album}/*").each do |tags_or_picture|
      #puts "tags path: #{tags}"
      tags_or_picture_filename = File.basename tags_or_picture
      #puts "tags_or_picture filename: #{tags_or_picture_filename}"
      next if tags_or_picture_filename[0] == '.'

      # Create directories in path2 and path3
      #
      if File.directory?("#{tags_or_picture}")
        if not validateDir "#{APP_CONFIG['upload_path2_inprogress']}/#{album_filename}/#{tags_or_picture_filename}", true
          puts "Could not write to your config upload_path2_inprogress."
          exit
        end
        if not validateDir "#{APP_CONFIG['upload_path3_done']}/#{album_filename}/#{tags_or_picture_filename}", true
          puts "Could not write to your config upload_path3_done."
          exit
        end

        Dir.glob("#{tags_or_picture}/*").each do |picture|
          process_picture(album_filename, picture, tags_or_picture_filename)
        end
      else
        process_picture(album_filename, tags_or_picture, '')
      end
    end

    #  Done processing pictures in album. 
    #  Move any file that may exist (including images that are not in allowed_ext)
    # in album from path1 to path3, and remove path1/album.
    moveToPath3 album_filename, APP_CONFIG['upload_path1_todo']
    if isEmpty album 
      
      # Success! Now move all pics from path2 to path3
      moveToPath3 album_filename, APP_CONFIG['upload_path2_inprogress']
      puts "Done with album: #{album_filename}"

      if photoset == false
        tagalbum = album_filename.gsub(' ','').downcase
        puts " ====> You probably want to create a set with these photos:"
        puts "http://www.flickr.com/photos/organize/"
        puts "http://www.flickr.com/photos/#{login.username}/tags/#{tagalbum}\n\n"
      else
        puts "http://www.flickr.com/photos/#{login.username}/sets/#{photoset['id']}\n\n"
      end
    else
      puts "NOT Done with album: #{album}\n\n"
    end
  end
  endTime = Time.now   #=> 2007-11-17 15:18:03 +0900
  elapsedSecs = endTime - startTime
  puts "All Done.  Took #{elapsedSecs} seconds, end %s" % startTime.strftime("%FT%T")
  
end



def process_picture album_filename, picture, tags_filename
  picture_filename = File.basename picture
  if not APP_CONFIG['allowed_ext'].include? File.extname(picture_filename).downcase
    puts "- #{File.extname(picture_filename)} are not allowed for upload, skipping (#{picture_filename})"
    return
  end
  
  # exclude dotfiles
  return if picture_filename[0] == '.'

  tags_filename += ",#{album_filename}"
  tags_filename += ",uploaded_by_rubyflickr"  # optionally comment this out.
  puts "- uploading '#{picture_filename}' in album '#{album_filename}' with tags: #{tags_filename}"

  begin
    # NOTE: encode not supported in ruby 1.8.7, but is in ruby  1.9.x
    picture_path = "#{picture}".encode("UTF-8") 
  rescue
    #puts "#{$!}"
    picture_path = "#{picture}"
  end
  encoded_tags = tags_filename.split(',').map{ |s| 
    # add quotes for multiple words tags
    begin
      s.encode("UTF-8")
    rescue
      s
    end
    %Q/"#{s}"/ 
  }
  if $noUpload
    picture_id = 1212
    sleep 2
  else
    begin
      picture_id = flickr.upload_photo picture_path, :title => picture_filename, :description => "", 
                               :tags =>encoded_tags.join(' '), :is_public => APP_CONFIG['is_public']
    rescue Timeout::Error => e
      puts "  OOPS: flickr.upload_photo: Timeout::Error - #{e.message}"
      picture_id = false
    rescue FlickRaw, Timeout, Timeout::Error, StandardError => e
      # http://stackoverflow.com/questions/10048173/why-is-it-bad-style-to-rescue-exception-e-in-ruby
      puts "  OOPS: flickr.upload_photo: #{e.message}"
      puts "  OOPS: e: #{e}"
      picture_id = false
    end
  end
  
  if not picture_id
    puts "\t upload failed. '#{picture_filename}' in album '#{album_filename}' with tags #{tags_filename}"
    return
  end
  
  # Success! Now move pic from path1 to path2
  r = Regexp.new(APP_CONFIG['upload_path1_todo'])
  newpicture = picture_path.gsub(r, APP_CONFIG['upload_path2_inprogress'])
  File.rename  picture_path, newpicture
  #puts "\t upload done. moved to #{newpicture}"
  
  # add to flickr set if it exists
  photoset = $all_sets.get_set_by_title(album_filename)
  if photoset 
    #puts "\t Adding pic to album '#{album_filename}' photoset #{photoset['id']}"
    if not $noUpload
      res = flickr.call "flickr.photosets.addPhoto", {'photoset_id' => photoset['id'], 'photo_id' => picture_id}
    end
  end
end


def moveToPath3 album_filename, from_path
  rgx = Regexp.new(from_path)
  album = "#{from_path}/#{album_filename}"

  Dir.glob("#{album}/*", File::FNM_DOTMATCH).each do |file_or_dir|
    next if ['.','..'].include? File.basename file_or_dir

    if File.directory?("#{file_or_dir}")
      Dir.glob("#{file_or_dir}/*", File::FNM_DOTMATCH).each do |picture|
        next if ['.','..'].include? File.basename picture
        newpicture = picture.gsub(rgx, APP_CONFIG['upload_path3_done'])
        File.rename picture, newpicture
      end
      if isEmpty file_or_dir 
        Dir.unlink file_or_dir
      end
    else
      newpicture = file_or_dir.gsub(rgx, APP_CONFIG['upload_path3_done'])
      File.rename  file_or_dir, newpicture
    end
  end
  if isEmpty album 
    Dir.unlink album
  end
end


def validateDir path, create
  if not create
    return !(path.nil? or !File.exists? path)
  else
    if not File.exist? path
      FileUtils.mkdir_p path
    else
      return File.directory? path
    end
  end
end

def isEmpty path
  Dir.glob("#{path}/*", File::FNM_DOTMATCH).each do |fn|
    #puts "isEmpty: checking #{fn}"
    fn_base = File.basename fn
    next if fn_base == '.'
    next if fn_base == '..'
    #puts "is not empty: #{path} -- #{fn_base}"
    return false
  end
  #puts "is empty: #{path}"
  return true
end

init
