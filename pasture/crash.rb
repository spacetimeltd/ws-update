require 'csv'
require 'pry'
require 'json'
require 'zip/zip'

@xref = JSON.parse IO.read('xref.json')
@revxref = JSON.parse IO.read('revxref.json')
@ihash = JSON.parse IO.read('ihash.json')
@chash = JSON.parse IO.read('chash.json')
@imageref = JSON.parse IO.read('imageref.json')
@au = JSON.parse IO.read('au.json')

#TODO @imageref ...

load './postproc.rb'
load './helpers.rb'

@rollout_ids = []
def spiderIds id

    stack = to_c @chash[id]

    binding.pry

    while !stack.empty?

        cid = stack.delete_at(0)

        @rollout_ids.push cid
        if @chash[cid]
            stack << to_c(@chash[cid].flatten!)
        end

        # the au ulrs still need the path updated to make sure it ends up in the
        # new category/section contents

        # so we have to add it to the @rollout_ids and see what happens in
        # postproc

    end
end

binding.pry

# find out what ids appear in multiple contents
multipath = @ihash.find_all { |z| z[1]['path'] =~ /:/ }
multipath.each { |x| puts x[0]+' is found on these pages: ', x[1]['path'] }

# then create a hash of these keyed by name instead of id
mphash = {}
@ihash.each do |z|
    id = z[0]
    if z[1]['path'] =~ /:/
        mphash[z[1]['name']] = z[1]
    end
end

glist = "gettingread inkitchen aroundhouse onmove foryourcomfort1 chrisspec".split

glist.each do |x|
    @rollout_ids = []
    spiderIds x
    puts @rollout_ids.count
end


binding.pry
#
# paul simon - blew that room away


csv_data = CSV.read 'update-data-regen.csv';
headers = csv_data.shift;
rhash = csv_data.map { |row| Hash[*headers.zip(row).flatten] };

csv_data = CSV.read 'original-data.csv';
headers = csv_data.shift;
rhash_old = csv_data.map { |row| Hash[*headers.zip(row).flatten] };


 # just create update sets of affected records instead of all
 # that is, find what needs updating and what records impact other's data
 # then just gather the affected records that have been updated
