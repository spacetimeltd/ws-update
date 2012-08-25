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

    binding.pry

    record = params[:record]
    mode = params[:mode]

    code = record['code']
    opts = record['options']
    code.gsub!( /(^\w*?);/, '\1#{mode};' )
    code.gsub!( /\((\w*?)\)/ , '(\1#{mode})' )
    code.gsub!( /=(\w*?)(&|$)/, '=\1#{mode}\2' )
    opts.gsub!( /\((\w*?)\)/ , '(\1#{mode})' )

    binding.pry

end

def postproc

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


        binding.pry

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
                fix_code :mode => 'old', :record => record
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
            next
        end
    end

    binding.pry

    rollout_data_hash.each_pair { |x,y| puts "#{x} <:> #{y['label']}" };

    # next we process the rest of the untouched records
    #   need to determine which records will be affected
    #       - anything that is in a section that is changed will be updated
    #   I think it's just the labels that need fixing.

    original_data_hash.each_pair do |id,record|
        if record['label']
            @rollout_ids.each do |rid|
                if record['label'].index rid
                    puts "#{record['id']} <:> #{record['name']} <:> #{record['label']}"
                end
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

         #if target['options']
            #code = target['code']
            #opts = target['options']
            #code.gsub! /(^\w*?);/, '\1old;'
            #code.gsub! /\((\w*?)\)/, '(\1old)'
            #code.gsub!(/=(\w*?)(&|$)/, '=\1old\2')
            #opts.gsub! /\((\w*?)\)/, '(\1old)'
            #else
                #target['code'].gsub! /$/, 'old'
        #end

    ##rollout_data_hash.each_pair do |id,record|

    ## these are the udated records including the amy updated
        ## 1. if it's a regular update the old record needs to be pulled
        ##    then added to the rollout data as the original id but with
        ##       new path, new code/options, fixed labels - and made not orderable!
        ## 2. if it's amy updated then only the path and label need to be
        ##    updated
        ##       and only update path if section is being among the updated.

        ##if @au.index id or anything
## check path, it it's indexed by 'name' then it shouldn't need changing
## I don't know if the section will work, why is path keyed to name?

        ## only thing else to do is process the labels, assuming code is
            ## unchanging
        ## the new ids will have to be used to index in the output hash

## the question now is
    ## when to remove the outdated original records
    ## they should be put in a list to update the labels and path and codes

    #binding.pry


    ## I can repeat the @rollout_ids list again to generate the fixed old records
    ## so that they can be added to the rollout after the fixed un-updated records
    ##

   ## the difference being, this time the ids should all be old style, except for
    ## the au members
    ##


    ## -Chop off what we just did and now the old array has to be fixed
    ## -Fix the labels and add the fixed records to the new hash
    ##
    #to_delete = rhash_old.shift(number_of_records)

    #rhash_old.each_index do |index|
        #record = rhash_old[index]
        #rollout_label = ""

        #if(record['label'])
            #labels = record['label'].split
            #labels.each do |label|
                #rollout_label += ((ids_hash[@xref[label]]) ? @xref[label] : label) + " "
            #end
        #end
        #rhash_old[index]['label'] = rollout_label
        #rhash_new[rhash_new.count+1] = rhash_old[index]
    #end

    ##
    ## -Remove problematic data - ie 'code', 'options', etc from obsolete records
    ## -Update path of obsolete records to place them in 'TODELETE' section
    ##

    #to_delete.each_index do |td|
        ## -to update the 'code' and 'options' data I'll have to parse and update
        ## this: see <to_delete-notes.txt>
        #target = to_delete[td]

        #if target['options']
            #code = target['code']
            #opts = target['options']
            #code.gsub! /(^\w*?);/, '\1old;'
            #code.gsub! /\((\w*?)\)/, '(\1old)'
            #code.gsub!(/=(\w*?)(&|$)/, '=\1old\2')
            #opts.gsub! /\((\w*?)\)/, '(\1old)'
            #else
                #target['code'].gsub! /$/, 'old'
        #end

        #target['path'] = 'TODELETE'

        ## then put the processed original data record back into the output array
        #rhash_new[rhash_new.count+1] = target
