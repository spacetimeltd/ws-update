require "nokogiri"
require "csv"
require "open-uri"
require "pry"
require "net/http"
#require "ruby-debug"
require "hpricot"
require "json"
require "zip/zip"

# here comes a section of functions for post-processing as one would expect
# you won't see these in use until the end, but they go up here anyway.

def genupload data
    CSV.open("update-data.csv", "wb") do |csv|
        csv << @uhead
        data.each { |a| csv << a }
    end
end

def gen_upload_zip(image_list)
    if !image_list.empty?
      file_name = "pictures.zip"
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
        id + " <-- unknown"
    end
end


# get xml payload
if File.exist? "catalog.xml"
    puts "catalog.xml has already been automatically downloaded, using existing"
else
    wsdata = open("http://store.wrightstuff.biz/catalog.xml")
    File.open("catalog.xml", "wb") { |f| f << wsdata.read }
end

wsdata = IO.read("catalog.xml")

# create xml document object
data = Nokogiri::XML(wsdata)    # consider manually setting encoding here
#***************************

items = data.css("Item[TableID=new-item]").map { |item| item } ;
itemids = data.css("Item[TableID=new-item]").map { |item| item['ID'] } ;
itemoptions = data.css("Item[TableID=new-item]").map { |item| item.css("ItemFieldOptions > Option") } ;

# now get the rest of the data
begin
xdata = IO.readlines("xdata.csv")
rescue
xdata = Hpricot.XML open("http://www.wrightstuff.biz/32-inch-rainbow-reacher.html")
xdata = xdata/"body > body > body"
xdata = xdata.first.children.map { |x| x.to_s }
xdata.delete "<br />"
xdata.map! { |x| JSON::parse x.split("<@>").to_s }
head = [ "id", "name", "label", "contents", "leaf", "product-url", "code" ]
csv = CSV.open("xdata.csv","wb")
csv << head
xdata.each { |x| csv << x }
csv.close
xdata = IO.readlines("xdata.csv")
end

xhead = xdata.shift
xparsed = xdata.map { |xd| CSV.parse_line xd }
xhash = {}
xparsed.each { |x| xhash[x.shift] = *x }

@ihash = {}
itemrecords = []

puts "Beginning processing 'contents' data..."
@chash = {}

items.each_with_index do |item, index|
    itemrecord = {}
    itemrecord['id'] = item['ID']

    item.element_children.each do |field|
        itemrecord[field['TableFieldID']] = field['Value']
    end


    begin
    itemrecord["leaf"] = xhash[item["ID"].upcase][3]
    rescue
        binding.pry
    end

    itemrecord["contents"] = xhash[item["ID"].upcase][2]
    if(itemrecord["contents"] != "")
        puts itemrecord["contents"]
        @chash[item["ID"]] = itemrecord["contents"]
    end

    if !itemoptions[index].none?

        puts itemoptions[index]
        options = itemoptions[index]
        opttype = options.at_css("Option").attr("Key")
        choices = options.css("OptionValue").map { |choice| choice.attr("Value") }
        outStr = opttype + " "
        choices.each { |c| outStr += "\"#{c}\" " }
        itemrecord["options"] = outStr.strip

    else

        itemrecord["options"] = nil

    end

    itemrecords.push itemrecord
    @ihash[item["ID"]] = itemrecord
end

#binding.pry

# now what? we have the itemrecords
# * current 'id' needs to be recorded for redirects - along with new id
# * images from tags must be downloaded and saved to appropriate file name
#   * file name should be predictable and contain field name or something
# * new seo friendly id must be made
#   * page title stripped of whitespace and common terms/ illegal characters
# redirects are full url
#Old Page URL   New Page URL
#http://www.wrightstuff.biz/adsc.html   http://www.wrightstuff.biz/adsc1.html

# now we work on the seo url construction
root = "http://www.wrightstuff.biz/"
redirects = {}

tr = []
trf = []
erf = []
orf = []
report = []
preport = []
rhash = {}
@xref = {}
@revxref = {}
@imageref = {}
log = []
dups = {}
orderable = []
norderable = []
modified = []
anomalies = []
@au = []
csv = CSV.open("redirects_updated.csv", "wb")
out = CSV.open("finalstage.csv", "wb")
out << itemrecords.first.keys
itemrecords.each do |rec|
    if rec['id'] =~ /-/
        anomalies.push "Already updated: " + rec['id']
        @au.push rec['id']
        next
    end
    if rec['name'] =~ /[^\w\s]/
        tr.push rec['name']
        trf.push rec['name'].gsub /\s+/, '-'
        trf.last.gsub! /\W+/, '-'
        trf.last.downcase!
        trf.last.gsub! /-s-/, "s-"    # I don't like this one
        result = trf.last
    else
        erf.push rec['name'].gsub /\s+/, '-'
        erf.last.downcase!
        result = erf.last
    end

    pattern = /(^|-)(and|or|if|but|for|of|the|in|to|with|about|how|a|be)($|-)/

    if result =~ pattern
        tmp = [result]
        while tmp.last =~ pattern do
            tmp.push tmp.last.gsub pattern, "-"
        end
        if tmp.last =~ /^-|-$/
            tmp.push tmp.last.gsub /^-|-$/, ""
        end
        if tmp.last =~ /--/
            tmp.push tmp.gsub /--/, "-"
        end
        orf.push tmp.last
        #log.push "#{result} ---> #{tmp.to_s} ---> #{orf.last}"
        log.push "#{result},#{tmp.join("\n")},#{orf.last}"
        result = orf.last
    else
        result.gsub! /^-|-$/, ""
        result.gsub! /--/, "-"
    end

    # dealing with duplicate names
    if dups[result] != nil
        dups[result] += 1
        result = result.concat dups[result].to_s
        modified.push result
    else
        dups[result] = 1
    end

    rhash[rec['id']] = result

    preport.push [rec['id'], rec['name'], result]
    report.push Hash["#{root}#{rec['id']}.html".to_sym => "#{root}#{result}.html"]
    redirects.merge! Hash["#{root}#{rec['id']}.html" => "#{root}#{result}.html"]

    # output the updated redirect data
    csv << ["#{root}#{rec['id']}.html", "#{root}#{result}.html"]

    # now prepare the images and then output the new product data
    todoList = [ 'image', 'inset', 'icon',
        'additional-image-1', 'additional-image-2', 'additional-image-3']
    todoList.each do |img|
            if rec[img] =~ /<img.*?src=http.*?>/

                itag = Nokogiri::HTML.parse(rec[img]).at_css 'img'
                source_url = itag.attribute('src').value
                iname = result + "-" + img
                puts "Ready to download #{img} from #{source_url} as #{iname}"
                rec[img] = iname
                begin
                    @imageref[rec['id']].push rec[img]
                rescue
                    @imageref[rec['id']] = [rec[img]]
                end
                if File.exist? "images/#{iname}"
                    puts "No need, file is already in the cache."
                    next
                end
                puts "Commencing download..."
                open("images/#{iname}","wb") { |file| file << open(source_url).read }
                puts "Success!"
            end
    end

    #binding.pry
    purl = rec["product-url"]
    if purl =~ /makinglifeeasier\//
        purl.gsub! /makinglifeeasier\/.*$/, "makinglifeeasier/#{result}.html"
    else
        puts purl + " is anomalous\n"
        anomalies.push purl + " from " + rec["name"] + " is anomalous!"
    end

    @xref[rec['id']] = result
    @revxref[result] = rec['id']

   rec['id'] = result
    out << rec.values

end
out.close
csv.close
# the original id, the name of the item, the new id derived from the name
CSV.open("id-conversion-report.csv", "wb") do |csv|
    csv << ["Original ID", "Name", "New ID"]
    preport.each { |pr| csv << pr }
end

# get ready for the xredirects
xredirects = Hash[CSV.read("makinglifeeasier-redirectrules.csv")]
xredirects.each { |red| red.inspect }
redhead = xredirects.shift
oldreds = []
xredirects.keys.each { |k| oldreds += xredirects[k].scan /\w[^\/]*$/ }
oldreds.map! do |o|
    oldurl = root + o
    newurl = "#{root}#{@xref[o.chomp(".html")]}.html"
    [oldurl, newurl]
end
newOldReds = {}
oldreds.each { |o| newOldReds.merge! Hash[*o] }
xredirects.each_key { |k| xredirects[k] = newOldReds[xredirects[k]] }
# xredirects.merge! newOldReds
# turns out I don't need newOldReds, really, cuz they're there already
csv = CSV.open("redirects_final.csv", "wb")
finalreds = Hash[*redhead]
finalreds.merge! xredirects
finalreds.merge! redirects
finalreds.each { |fr| csv << fr }
csv.close

#
#
# now all we have left to do (as if) is update the label and contents data
rejects = {}
cnthash = {}

alldata = CSV.read("finalstage.csv");
ahd = alldata.shift
li = ahd.index "label"
ci = ahd.index "contents"
pi = ahd.index "path"

alldata.each_index do |i|
    # first the label field
    if alldata[i][li] == ""
        puts "#{alldata[i][0]} contains no label data. Moving on..."
    else
        puts "#FOUND# ID( #{alldata[i][0]} ) --> LABEL( #{alldata[i][li]} )"

        newlab = alldata[i][li].split(" ").map do |lab|
            @xref[lab]
        end
        if newlab != ""
            out = newlab.join " "
            alldata[i][li] = newlab.join " "
        else
            alldata[i][li] += "failed on ID( #{alldata[i][0]} )"
        end

        puts "#UPDATING# ==> RESULT( #{out} )"
    end

    # then the contents
    puts "Checking for contents data..."
    if alldata[i][ci] == ""
        puts "#{alldata[i][0]} contains no contents data. Moving on..."
    else
        contents = alldata[i][ci]
        puts "#CONVERTING# " + contents
        contents = contents.gsub(/(:(\w*?)(?=\W))/, "\\2").gsub(/\(|\)/, "")
        out = "#UPDATING " + contents.downcase!
        contents = contents.split
        contents.each_index do |ii|
            if contents[ii] =~ /\|/
                contents[ii].gsub! /\|/, ""
            end
            verified = @xref[contents[ii]]
            if verified == nil
                #debugger
                id = alldata[i][0]
                verified = contents[ii] # + " <-- *** Unknown ID *** "

                if rejects[verified] != nil
                    rejects[verified].push "#{id}/#{@revxref[id]}"
                else
                    rejects[verified] = ["#{id}/#{@revxref[id]}"]
                end
            else
                puts "Locating and updating path for product (#{verified})"
                identified = alldata.find { |a| a[0] == verified }


                if identified[pi] == ""
                    identified[pi] = alldata[i][0]
                    @ihash[@revxref[identified[0]]]['path'] = @revxref[alldata[i][0]]
                else
                    identified[pi] += ":#{alldata[i][0]}"
                    @ihash[@revxref[identified[0]]]['path'] += ":#{@revxref[alldata[i][0]]}"
                end
            end
            contents[ii] = verified
        end

        if contents.length > 1
            contents = [contents.join(" ")]
        end

        contents = contents.pop
        alldata[i][ci] = contents

        out += " ==> RESULT( #{contents} )"
        puts out    # heh heh
    end
end;

CSV.open("full-update-data.csv", "wb") do |csv|
    csv << itemrecords.first.keys
    alldata.each { |a| csv << a }
end

File.open("unknown.txt", "wb") do |file|
    rejects.each_pair do |x,y|
        file << x
        file << "\n"
        file << "Found in 'contents' on page(s):\n"
        y.each { |y| file << y + "\n" }
        file << "\n"
    end
end


# load 'data.csv' and 'final-update-data.csv' to separate hashes so that regardless of
# the input field order the required output format can be achieved

# load the new updated data into an array of hashes
csv_data = CSV.read 'full-update-data.csv';
headers = csv_data.shift;
update_hash_array = csv_data.map { |row| Hash[*headers.zip(row).flatten] };

# now convert the updated data into a hash of hashes indexed by the old id's
update_data_xref = {}
update_hash_array.each do |record|
    update_data_xref[@revxref[record['id']]] = record
end;

# load the original data into a hash indexed by old id
csv_data = CSV.read 'original-data.csv';
headers = csv_data.shift;
original_data_hash = {}
csv_data.each do |row|
# the zip method creates the hash key,value pairs like a zipper
    record_to_hash = *headers.zip(row).flatten
# then I extract the first pair which contains the id
    id_pair = record_to_hash.shift 2
# pop out the id, discarding the field name
    id = id_pair.pop
# then assign it to the new hash
    original_data_hash[id] = Hash[*record_to_hash]

end;

    puts "The following id's from the old data do not exist in the update \
            (should be caused if they're already updated):\n"

# now copy the unchanging pieces of original data to the update hash

original_data_hash.each_pair do |id,data|

# need to copy:
    # code, abstract, headline, orderable, taxable, description, family, path,
    # gift-certificate, caption
   #binding.pry
# an alternative is to copy everything except:
    # id, product-url, label

    if !update_data_xref[id]
        puts [id]
        next
    end

    if data['path'] == "TODELETE"
        puts "Need to do something about the TODELETE elements"
    end

    update_data_xref[id]['code'] = data['code']
    update_data_xref[id]['abstract'] = data['abstract']
    update_data_xref[id]['headline'] = data['headline']
    update_data_xref[id]['orderable'] = data['orderable']
    update_data_xref[id]['taxable'] = data['taxable']
    update_data_xref[id]['description'] = data['description']
    update_data_xref[id]['family'] = data['family']
    update_data_xref[id]['path'] = data['path']
    update_data_xref[id]['gift-certificate'] = data['gift-certificate']
    update_data_xref[id]['caption'] = data['caption']

# then output to the new file


end;

    puts "The following id's from the update csv were not found in the old data:\n"

# - and regenerate the output file as 'update-data-regen.csv'
# The reason I'm doing it this way is because my meds are all messed up and I
# can barely think - so fixing the output now is less dangerous than a rewrite

output_csv = CSV.open("update-data-regen.csv", "wb")
output_csv << update_data_xref.first[1].keys
update_data_xref.each_pair do |old_id,new_record_hash|

    # make sure there's no records in the new data that don't exist in the old
    if !original_data_hash[old_id]
        puts old_id
        binding.pry
    end

    output_csv << new_record_hash.values
end;
output_csv.close

# I'll write the important globals to file in case I break out with the
# post-processing
IO.binwrite("xref.json", @xref.to_json)
IO.binwrite("revxref.json", @revxref.to_json)
IO.binwrite("ihash.json", @ihash.to_json)
IO.binwrite("chash.json", @chash.to_json)
IO.binwrite("imageref.json", @imageref.to_json)
IO.binwrite("au.json", @au.to_json)

# don't forget to change the old data to put it in the new path 'TODELETE'

def rollout(percent_to_update)

# load 'data.csv' and 'finalstage.csv' to separate hashes so that regardless of
# the input field order the required output format can be achieved

    #
    # -Get all the old stuff and all the new stuff to combine together
    #
    csv_data = CSV.read 'update-data-regen.csv';
    headers = csv_data.shift;
    rhash = csv_data.map { |row| Hash[*headers.zip(row).flatten] };

    csv_data = CSV.read 'original-data.csv';
    headers = csv_data.shift;
    rhash_old = csv_data.map { |row| Hash[*headers.zip(row).flatten] };

    number_of_records = (rhash.count() * (percent_to_update.to_f()/100)).floor()
    rhash_new = {}
    ids_hash = {}

    #
    # -Add the new stuff
    # -Fix those labels
    #
    number_of_records.times do |index|
        ids_hash[rhash[index]["id"]] = "";
        rhash_new[index] = rhash[index]
    end

    rhash_new.each_with_index do |record,index|
        record = record.pop
        rollout_label = ""

        if(record['label'])
            labels = record['label'].split
            labels.each do |label|
                rollout_label += ((ids_hash[label]) ? label : @revxref[label]) + " "
            end
        end
        rhash_new[index]['label'] = rollout_label

        target = rhash_new[index]

        if target['options']
            code = target['code']
            opts = target['options']
            code.gsub! /(^\w*?);/, '\1tmp;'
            code.gsub! /\((\w*?)\)/, '(\1tmp)'
            code.gsub!(/=(\w*?)(&|$)/, '=\1tmp\2')
            opts.gsub! /\((\w*?)\)/, '(\1tmp)'
            else
                target['code'].gsub! /$/, 'tmp'
        end

    end

    #
    # -Chop off what we just did and now the old array has to be fixed
    # -Fix the labels and add the fixed records to the new hash
    #
    to_delete = rhash_old.shift(number_of_records)

    rhash_old.each_index do |index|
        record = rhash_old[index]
        rollout_label = ""

        if(record['label'])
            labels = record['label'].split
            labels.each do |label|
                rollout_label += ((ids_hash[@xref[label]]) ? @xref[label] : label) + " "
            end
        end
        rhash_old[index]['label'] = rollout_label
        rhash_new[rhash_new.count+1] = rhash_old[index]
    end

    #
    # -Remove problematic data - ie 'code', 'options', etc from obsolete records
    # -Update path of obsolete records to place them in 'TODELETE' section
    #

    to_delete.each_index do |td|
        # -to update the 'code' and 'options' data I'll have to parse and update
        # this: see <to_delete-notes.txt>
        target = to_delete[td]

        if target['options']
            code = target['code']
            opts = target['options']
            code.gsub! /(^\w*?);/, '\1old;'
            code.gsub! /\((\w*?)\)/, '(\1old)'
            code.gsub!(/=(\w*?)(&|$)/, '=\1old\2')
            opts.gsub! /\((\w*?)\)/, '(\1old)'
            else
                target['code'].gsub! /$/, 'old'
        end

        target['path'] = 'TODELETE'

        # then put the processed original data record back into the output array
        rhash_new[rhash_new.count+1] = target
    end
#
###############################################################################
# TODO - need to pick out the rollout redirects, which ones?
# TODO - prepare the pictures for upload - should I preserve the original images
# for the TODELETE set? Original data doesn't have images, does it?
###############################################################################
#
    #binding.pry

    #
    # -Output to csv file
    # - but first specify the exact fields and field order for the output
    #

    keys = "id code abstract sale-price product-url headline isbn orderable
        google-base-product-type options ship-weight page-title taxable
        availability description family price merchant-category condition
        path gift-certificate label manufacturer-part-number caption keywords
        brand upc name inset icon additional-image-1 additional-image-2
        additional-image-3 image download leaf".split

    rollout_csv = CSV.open('rollout_data.csv', 'wb')
    # keys = rhash_new.first[1].keys
    rollout_csv << keys
    rhash_new.each do |record|

        row = []
        keys.each do |key|
            row.push record[1][key]
        end
        rollout_csv << row
    end
    rollout_csv.close
end

binding.pry


