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
  if not validateDir(APP_CONFIG['upload_path1_todo'],false)
    puts "Your config upload_path1_todo doesn't exist."
    exit
  end
  if APP_CONFIG['upload_path1_todo'].empty? 
    puts "Your config upload_path1_todo is empty."
    exit
  end
  t = Time.now   #=> 2007-11-17 15:18:03 +0900
  puts "Processing #{APP_CONFIG['upload_path1_todo']} %s" % t.strftime("%FT%T")
  
  login = flickr.test.login
  puts "You are now authenticated as #{login.username}"
  
  Dir.glob("#{APP_CONFIG['upload_path1_todo']}/*").each do |album|
    next if album[0] == '.'
    album_filename = File.basename album
    #puts "album: #{album}"
    #puts "album filename: #{album_filename}"

    if not validateDir "#{APP_CONFIG['upload_path2_inprogress']}/#{album_filename}", true
      puts "Could not write to your config upload_path2_inprogress."
      exit
    end

    # Check if destination album exists
    photoset = $all_sets.get_set_by_title(album_filename)
    if photoset == false
      puts "\t Uploading album '#{album_filename}' as tagged pictures, no photoset found"
    else
      puts "\t Uploading album '#{album_filename}' to flickr photoset #{photoset['id']}"
    end

    Dir.glob("#{album}/*").each do |tags_or_picture|
      #puts "tags path: #{tags}"
      tags_or_picture_filename = File.basename tags_or_picture
      #puts "tags_or_picture filename: #{tags_or_picture_filename}"
      next if tags_or_picture_filename[0] == '.'


      if File.directory?("#{tags_or_picture}")
        if not validateDir "#{APP_CONFIG['upload_path2_inprogress']}/#{album_filename}/#{tags_or_picture_filename}", true
          puts "Could not write to your config upload_path2_inprogress."
          exit
        end
        Dir.glob("#{tags_or_picture}/*").each do |picture|
          process_picture(album_filename, picture, tags_or_picture_filename)
        end
        if isEmpty tags_or_picture 
          Dir.unlink tags_or_picture
        end
      else
        process_picture(album_filename, tags_or_picture, '')
      end
    end
    if isEmpty album 
      Dir.unlink album  # in path1
      oldname = "#{APP_CONFIG['upload_path2_inprogress']}/#{album_filename}"
      newname = "#{APP_CONFIG['upload_path3_done']}/#{album_filename}"
      File.rename oldname, newname
      puts "Done with album: #{album}\n\n"
    else
      puts "NOT Done with album: #{album}\n\n"
    end
  end
end



def process_picture album_filename, picture, tags_filename
  picture_filename = File.basename picture
  if not APP_CONFIG['allowed_ext'].include? File.extname(picture_filename)
    puts "- #{File.extname(picture_filename)} are not allowed for upload, file was (#{picture_filename})"
    return
  end
  
  # exclude dotfiles
  return if picture_filename[0] == '.'

  if not tags_filename
    tags_filename += ','
  end
  tags_filename += "#{album_filename}"
  tags_filename += ",uploaded_by_rubyflickr"  # comment this out if necessary.
  puts "- will upload '#{picture_filename}' in album '#{album_filename}' with tags: #{tags_filename}"

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
    picture_id = flickr.upload_photo picture_path, :title => picture_filename, :description => "", 
                               :tags =>encoded_tags.join(' '), :is_public => APP_CONFIG['is_public']
  end
  
  if not picture_id
    puts "\t upload failed. '#{picture_filename}' in album '#{album_filename}' with tags #{tags_filename}"
    return
  end
  
  # Success! Now move pic from path1 to path2
  r = Regexp.new(APP_CONFIG['upload_path1_todo'])
  newpicture = picture_path.gsub(r, APP_CONFIG['upload_path2_inprogress'])
  File.rename  picture_path, newpicture
  puts "\t upload done. moved to #{newpicture}"
  
  # add to album if it exists
  photoset = $all_sets.get_set_by_title(album_filename)
  if photoset 
    puts "\t Adding pic to album '#{album_filename}' photoset #{photoset['id']}"
    if not $noUpload
      res = flickr.call "flickr.photosets.addPhoto", {'photoset_id' => photoset['id'], 'photo_id' => picture_id}
    end
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
  Dir.glob("#{path}/*").each do |fn|
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
