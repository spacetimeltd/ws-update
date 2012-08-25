
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

