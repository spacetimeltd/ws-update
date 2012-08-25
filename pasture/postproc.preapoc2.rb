def postproc

# load 'data.csv' and 'finalstage.csv' to separate hashes so that regardless of
# the input field order the required output format can be achieved

    #
    # -Get all the old stuff and all the new stuff to combine together
    #

    csv_data = CSV.read 'update-data-regen.csv', :encoding => 'cp1252';
    headers = csv_data.shift;
    rhash = csv_data.map { |row| Hash[*headers.zip(row).flatten] };
    update_data_xref = {}
    rhash.each do |record|
        update_data_xref[@revxref[record['id']]] = record
    end

    csv_data = CSV.read 'original-data.csv', :encoding => 'cp1252';
    headers = csv_data.shift;
    original_data_hash = {}
    csv_data.each do |row|
        record_to_hash = *headers.zip(row).flatten
        id_pair = record_to_hash.shift 2
        id = id_pair.pop
        original_data_hash[id] = Hash[*record_to_hash]
    end

    number_of_records = @rollout_ids.count
    rollout_data_hash = {}
    ids_hash = {}

    #
    # -add the new stuff
    # -fix those labels
    #

    @rollout_ids.each do |id|
        if update_data_xref[id]
# if id exists in the updated data then we take it
            rollout_data_hash[id] = update_data_xref[id]
            ids_hash[id] = true
        elsif original_data_hash[id]
# otherwise, it's one of amy's updates so use the original data
            rollout_data_hash[id] = original_data_hash[id]
            rollout_data_hash[id].merge! 'id' => id # original has no new id
        end
    end

    rollout_data_hash.each_pair do |key,val|

        record = val
        id = record['id']
        rollout_label = ""

        if(record['label'])
            labels = record['label'].split
            labels.each do |label|
                begin
                rollout_label +=
                    ((ids_hash[label]) ? label : @revxref[label]) + " "
                rescue
                    puts "au detected, reversing: #{id} => #{label}"
                    begin
                        label = @xref[label]
                    rescue
                        binding.pry
                    end
                    rollout_label +=
                        ((ids_hash[label]) ? label : @revxref[label]) + " "
                end
            end
        end

             binding.pry


        rollout_data_hash[id]['label'] = rollout_label.strip

        target = rollout_data_hash[id]

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

    binding.pry

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
