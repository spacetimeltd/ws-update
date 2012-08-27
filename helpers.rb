
# here comes a section of functions for post-processing as one would expect
# you won't see these in use until the end, but they go up here anyway.

def path_to_parent path, rdh, xpaths
    puts "this is the path that doesn't need updating: #{path}"
    parent = path.split(':').last
    begin
    xpaths.delete xpaths.find { |x| rdh[@xref[x]]['name'] =~ /#{parent}/ }
    rescue
        binding.pry
    end
end

def genupload data
    CSV.open("update-data.csv", "wb") do |csv|
        csv << @uhead
        data.each { |a| csv << a }
    end
end

def gen_upload_zip(image_list, mainId)
    if !image_list.empty?
      file_name = "#{mainId}_pictures.zip"
      #t = Tempfile.new("my-temp-filename-#{Time.now}")
      #t = Tempfile.new("my-temp-filename")
      Zip::ZipOutputStream.open(file_name) do |z|
        image_list.each do |img|
          #title = img.title
          #title += ".jpg" unless title.end_with?(".jpg")
          z.put_next_entry(img)
          File.open("images/#{img}", "rb") { |f| z.print f.read }
        end
      end
      #send_file t.path, :type => 'application/zip',
                             #:disposition => 'attachment',
                             #:filename => file_name

      return true
    end
end

def getpath id
    begin
        to_c @ihash[id]['path']
    rescue
        binding.pry
        id + " <-- unknown"
    end
end

def to_c cntstr
    if cntstr =~ /|/
        cntstr.gsub!(/\|/,"")
    end
    out = cntstr.scan(/[^\(: ][\w-]*?(?=[ \)])/)
    return out.map { |o| o.downcase }
end

# don't forget these:
# :|12-INCH-MOEN-PEENED-GRAB-BAR| :|18-INCH-MOEN-PEENED-GRAB-BAR| :|36-INCH-MOEN-PEENED-GRAB-BAR|

