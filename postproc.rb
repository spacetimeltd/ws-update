def fix_labels labels
    rollout_label = []

    labels.each do |label_value|
        if @rollout_ids.index @revxref[label_value]
            # this is a regularly updated value the needs no alteration
            rollout_label.push label_value
        elsif @au.index label_value
            # this is an amy updated id, needs no alteration
            rollout_label.push label_value
        elsif  @rollout_ids.index label_value
            # it's among the chosen but it hasn't gotten the memo yet
            rollout_label.push @xref[label_value]
        else
            # check if it has been updated when it shouldn't have somehow
            if @revxref[label_value]
                rollout_label.push @revxref[label_value]
            else
                rollout_label.push label_value
            end
        end
    end
    return rollout_label.join(" ")
end

def fix_codes params

    record = params[:record]
    mode = params[:mode]

    code = record['code']
    opts = record['options']
    code.gsub!( /(^\w*?);/, '\1'+"#{mode};" )
    code.gsub!( /\((\w*?)\)/ ,'\1'+"(#{mode})" )
    code.gsub!( /=(\w*?)(&|$)/, '=\1'+mode+'\2' )
    opts.gsub!( /\((\w*?)\)/ , '\1'+"(#{mode})" )

end

def postproc mainId

# load 'data.csv' and 'finalstage.csv' to separate hashes so that regardless of
# the input field order the required output format can be achieved

    #
    # -Get all the old stuff and all the new stuff to combine together
    #

    csv_data = CSV.read 'update-data-regen.csv', :encoding => 'cp1252';
    headers = csv_data.shift;
    rhash = csv_data.map { |row| Hash[*headers.zip(row).flatten] };
    update_data_hash = {}
    rhash.each do |record|
        update_data_hash[@revxref[record['id']]] = record
    end

    csv_data = CSV.read 'original-data.csv', :encoding => 'cp1252';
    headers = csv_data.shift;
    rhash_old = csv_data.map { |row| Hash[*headers.zip(row).flatten] }
    original_data_hash = {}
    rhash_old.each do |record|
        original_data_hash[record['id']] = record
    end

    number_of_records = @rollout_ids.count
    rollout_data_hash = {}
    ids_hash = {}

    #
    # -add the new stuff plus the old new stuff so it can neutralized
    # -fix those labels, codes, options, paths, and orderables
    #

        ## 1. if it's a regular update the old record needs to be pulled
        ##    then added to the rollout data as the original id but with
        ##       new path, new code/options, fixed labels - and made not orderable!
        ## 2. if it's amy updated then only the path and label need to be
        ##    updated
        ##       and only update path if section is being among the updated.

    @rollout_ids.each do |id|
        if update_data_hash[id]
        # if id exists in the updated data then we fix the labels
            record = update_data_hash[id]
            if record['label']
                record['label'] = fix_labels record['label'].split
            end
            # then fix the code and options
            if record['options']
                fix_codes :mode => 'tmp', :record => record
            else
                record['code'].gsub!( /$/, 'tmp' )
            end
            # then we add it to the output hash under it's new id
            rollout_data_hash[@xref[id]] = record

        # but remember to keep the original in the output
            record = original_data_hash.delete id
            # not forgetting to update labels and path and codes/options
            if record['label']
                record['label'] = fix_labels record['label'].split
            end
            record['path'] = 'TODELETE'
            record['orderable'] = 'No'
            if record['options']
                fix_codes :mode => 'old', :record => record
            else
                record['code'].gsub!( /$/,'old' )
            end
            # add to output hash to update server w/new status of old id
            rollout_data_hash[id] = record

        elsif original_data_hash[id]
        # otherwise, it's one of amy's updates so use the original data
            record = original_data_hash.delete id
            # right after checking the path and fixing labels
            puts record['path'] + " <== path"
            if record['label']
               record['label'] = fix_labels record['label'].split
            end
            rollout_data_hash[id] = record
        else
        # or in the worst case it's completely unkown
             @logfile << "can't identify #{id}\n"
            next
        end
    end

    #rollout_data_hash.each_pair { |x,y| puts "#{x} <:> #{y['label']}" };

    rollout_data_hash.each_pair do |id, record|
        if @mphash[@revxref[record['id']]]
            @logfile << "multipath record: \
                #{id} => #{@mphash[@revxref[id]]}, path: #{record['path']}"
        end
    end;

    # next we process the rest of the untouched records
    #   need to determine which records will be affected
    #       - anything that is in a section that is changed will be updated
    #   I think it's just the labels that need fixing.

    original_data_hash.each_pair do |id,record|
        if record['label']
            found = false
            record['label'].split.each do |label|
                if @rollout_ids.index label
                    found = true
                    break
                end
            end
            if found
                record['label'] = fix_labels record['label'].split
                rollout_data_hash[id] = record
            end
# where to add to the output hash???
        end
    end;

#
###############################################################################
# TODO - need to pick out the rollout redirects, which ones?
# TODO - prepare the pictures for upload - should I preserve the original images
# for the TODELETE set? Original data doesn't have images, does it?
###############################################################################
#

    #
    # - Gather redirect for rollout set
    # - Output redirects to csv file
    #

    rollout_redirects_csv = CSV.open(mainId+'_rollout_redirects.csv', 'wb')

    redirects = Hash[CSV.read("redirects_final.csv")]
    rollout_redirects_csv << redirects.shift # start the output set with the header
    redref = {}
    redirects.each_pair do |old,new|

        oid = old.sub /http.*\/(\w*)?\.html/, '\1'
        nid = new.sub /http.*\/([\w-]*)?\.html/, '\1'

        redref[oid] = [old,new]

    end

    # separate the pre-existing redirects and add to rollout_redirects_csv set
    redref.each do |red|
        rollout_redirects_csv << red[1]
        if red[0] == '100gift'
            break
        end
    end

    # then grab the redirects for the rollout set
    @rollout_ids.each { |id| rollout_redirects_csv << redref[id] unless !redref[id] }

    rollout_redirects_csv.close

    #
    # Grab the images and prepare for upload
    #

    image_list = []
    rollout_data_hash.each do |rd|
        "icon inset image additional-image-1 additional-image-2 additional-image-3".split.each do |img|
            if rd[1][img] != nil && rd[1][img] != ""
                image_list.push rd[1][img]
                #puts rd[1][img]
            end
        end
    end

    #gen_upload_zip(image_list, mainId)

    #
    # -Output to csv files
    # - but first specify the exact fields and field order for the output
    #

    keys = "id code abstract sale-price product-url headline isbn orderable
        google-base-product-type options ship-weight page-title taxable
        availability description family price merchant-category condition
        path gift-certificate label manufacturer-part-number caption keywords
        brand upc name inset icon additional-image-1 additional-image-2
        additional-image-3 image download leaf".split

    rollout_csv = CSV.open(mainId+'_rollout_data_final.csv', 'wb')
    rollout_csv << keys
    rollout_data_hash.each do |record|

        row = []
        keys.each do |key|
            row.push record[1][key]
        end
        rollout_csv << row
    end
    rollout_csv.close

    #binding.pry

end




    #cat rf.rb.log | grep 'identify' | less
#

def postprocpercent mainId

# load 'data.csv' and 'finalstage.csv' to separate hashes so that regardless of
# the input field order the required output format can be achieved
    # some debug variables
    unids = {}
    # ********************

    #
    # -Get all the old stuff and all the new stuff to combine together
    #

    csv_data = CSV.read 'update-data-regen.csv', :encoding => 'cp1252';
    headers = csv_data.shift;
    rhash = csv_data.map { |row| Hash[*headers.zip(row).flatten] };
    update_data_hash = {}
    rhash.each do |record|
        update_data_hash[@revxref[record['id']]] = record
    end

    csv_data = CSV.read 'original-data.csv', :encoding => 'cp1252';
    headers = csv_data.shift;
    rhash_old = csv_data.map { |row| Hash[*headers.zip(row).flatten] }
    original_data_hash = {}
    rhash_old.each do |record|
        original_data_hash[record['id']] = record
    end

    number_of_records = @rollout_ids.count
    rollout_data_hash = {}
    ids_hash = {}

    #
    # -add the new stuff plus the old new stuff so it can neutralized
    # -fix those labels, codes, options, paths, and orderables
    #

        ## 1. if it's a regular update the old record needs to be pulled
        ##    then added to the rollout data as the original id but with
        ##       new path, new code/options, fixed labels - and made not orderable!
        ## 2. if it's amy updated then only the path and label need to be
        ##    updated
        ##       and only update path if section is being among the updated.

    @rollout_ids.each do |id|
        if update_data_hash[id]
        # if id exists in the updated data then we fix the labels
            record = update_data_hash[id]
            if record['label']
                record['label'] = fix_labels record['label'].split
            end
            # then fix the code and options
            if record['options']
                fix_codes :mode => 'tmp', :record => record
            else
                record['code'].gsub!( /$/, 'tmp' )
            end
            # then we add it to the output hash under it's new id
            rollout_data_hash[@xref[id]] = record

        # but remember to keep the original in the output
            record = original_data_hash.delete id
            # not forgetting to update labels and path and codes/options
            if record['label']
                record['label'] = fix_labels record['label'].split
            end
            record['path'] = 'TODELETE'
            record['orderable'] = 'No'
            if record['options']
                fix_codes :mode => 'old', :record => record
            else
                record['code'].gsub!( /$/,'old' )
            end
            # add to output hash to update server w/new status of old id
            rollout_data_hash[id] = record

        elsif original_data_hash[id]
        # otherwise, it's one of amy's updates so use the original data
            record = original_data_hash.delete id
            # right after checking the path and fixing labels
            puts record['path'] + " <== path"
            if record['label']
               record['label'] = fix_labels record['label'].split
            end
            rollout_data_hash[id] = record
        else
        # or in the worst case it's completely unkown
            puts "can't identify #{id}"
            unids.push id
            next
        end
    end

    binding.pry

    rollout_data_hash.each_pair do |id, record|
        if @mphash[id]
            puts "#{id} => #{@mphash[id]}, path: #{record['path']}"
            binding.pry
            # check the mphash result ids to see if they are among the rollout
            # set, why? if they're not equal to what's in the path then the
            # pages corresponding to those id's must have their contents updated
            # manually.
        end
    end


    # next we process the rest of the untouched records
    #   need to determine which records will be affected
    #       - anything that is in a section that is changed will be updated
    #   I think it's just the labels that need fixing.

    original_data_hash.each_pair do |id,record|
        if record['label']
            found = false
            record['label'].split.each do |label|
                if @rollout_ids.index label
                    found = true
                    break
                end
            end
            if found
                record['label'] = fix_labels record['label'].split
                rollout_data_hash[id] = record
            end
# where to add to the output hash???
        end
    end;

#
###############################################################################
# TODO - need to pick out the rollout redirects, which ones?
# TODO - prepare the pictures for upload - should I preserve the original images
# for the TODELETE set? Original data doesn't have images, does it?
###############################################################################
#

    #
    # - Gather redirect for rollout set
    # - Output redirects to csv file
    #

    rollout_redirects_csv = CSV.open(mainId+'_rollout_redirects.csv', 'wb')

    redirects = Hash[CSV.read("redirects_final.csv")]
    rollout_redirects_csv << redirects.shift # start the output set with the header
    redref = {}
    redirects.each_pair do |old,new|

        oid = old.sub /http.*\/(\w*)?\.html/, '\1'
        nid = new.sub /http.*\/([\w-]*)?\.html/, '\1'

        redref[oid] = [old,new]

    end

    # separate the pre-existing redirects and add to rollout_redirects_csv set
    redref.each do |red|
        rollout_redirects_csv << red[1]
        if red[0] == '100gift'
            break
        end
    end

    # then grab the redirects for the rollout set
    @rollout_ids.each { |id| rollout_redirects_csv << redref[id] unless !redref[id] }

    rollout_redirects_csv.close

    #
    # Grab the images and prepare for upload
    #

    image_list = []
    rollout_data_hash.each do |rd|
        "icon inset image additional-image-1 additional-image-2 additional-image-3".split.each do |img|
            if rd[1][img] != nil && rd[1][img] != ""
                image_list.push rd[1][img]
                #puts rd[1][img]
            end
        end
    end

    #gen_upload_zip(image_list, mainId)

    #
    # -Output to csv files
    # - but first specify the exact fields and field order for the output
    #

    keys = "id code abstract sale-price product-url headline isbn orderable
        google-base-product-type options ship-weight page-title taxable
        availability description family price merchant-category condition
        path gift-certificate label manufacturer-part-number caption keywords
        brand upc name inset icon additional-image-1 additional-image-2
        additional-image-3 image download leaf".split

    rollout_csv = CSV.open(mainId+'_rollout_data_final.csv', 'wb')
    rollout_csv << keys
    rollout_data_hash.each do |record|

        row = []
        keys.each do |key|
            row.push record[1][key]
        end
        rollout_csv << row
    end
    rollout_csv.close

    #binding.pry

end


