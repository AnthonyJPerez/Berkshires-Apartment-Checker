require 'rubygems'
require 'mechanize'
require 'date'


APT_TYPES = {
	:_1B_1Ba => 'Z000000001',	# 1/1
	:_2B_1Ba => 'Z000000002',	# 2/1
	:_2B_2Ba => 'Z000000005'	# 2/2
}

LEASE_LENGTHS = {
	:MONTH_1 => "12",
	:MONTH_2 => "37",
	:MONTH_3 => "14",
	:MONTH_4 => "38",
	:MONTH_5 => "39",
	:MONTH_6 => "2",
	:MONTH_7 => "3",
	:MONTH_8 => "4",
	:MONTH_9 => "5",
	:MONTH_10 => "6",
	:MONTH_11 => "7",
	:MONTH_12 => "8",
	:MONTH_13 => "9" 
}

MOVEIN_DATE = Date.new(2013, 1, 3)


## a == Mechanize library
## date == desired Move-in Date
## apartmentType == size of the apartment
## leaseLength == length of the lease, in months
def getListings(a, date, apartmentType, leaseLength)
	# Grab the property search page
	results = nil
	a.get('http://property.onesite.realpage.com/ol/?s=1001107') do |page|
		# Submit the form
	    results = page.form_with(:name => 'Form1') do |search|
	    	#puts search.inspect
	        search['cfaSearchCriteria$cfaSearchCriteria$txtDateNeeded'] = date
	        search['cfaSearchCriteria$cfaSearchCriteria$lstApartmentTypes'] = apartmentType
	        search['cfaSearchCriteria$cfaSearchCriteria$lstLeaseTerms'] = leaseLength
	    end.submit
	end

	# Parse each row in the tables
	apartments = results.search('table > tbody > .OtherMatchedApartments, table > tbody > .ExactMatchedApartments').map do |tr|
		# Extract the apartment listings as an array of strings
		listings = tr.search('td').map do |td|
	        x = td.text.delete("\r\n,").strip
	        x.gsub!(/(\s)+/, '\1')
	        x.gsub!(/^\$(.*)-(.*)/, '$\1')
	        x
		end

		# Remove unnecessary information (removing index 3, 4)
		listings = listings[0..2] << listings[5]

		# Return an array of important information of each listing
		# [Apt #, Date Available, Apt Type, Cost]
		listings
	end

	return apartments
end


#######
#######

M = Mechanize.new { |agent|
    agent.user_agent_alias = "Mac Safari"
}


apartments = []
threads = []

# Submit the form for each type of apartment. Use a 
# thread for each form submission, to speed up the process.
APT_TYPES.each do |apt_size_key, apt_size|
	threads << Thread.new {
		getListings(M, '01/03/2013', apt_size, LEASE_LENGTHS[:MONTH_7])
	}
end

# Sync all of the threads
threads.each do |t|
	t.join
end

# Grab all of the data out of each thread push them all into one array
threads.each do |t|
	apartments += t.value
end

# Filter our listings
apartments.select! do |apt|
	# Filter out apartments > $1800/mo
	money = (1800 > apt[3].delete("$").to_i) 
	begin
		available = Date.strptime(apt[1], "%m/%d/%Y")
	rescue
		available = Date.strptime(Date.today.to_s, "%Y-%m-%d")
	end
	# Filter out apts not availale within a month's window
	date = (available <=> MOVEIN_DATE - 45) >= 0 and (available <=> MOVEIN_DATE + 14) <= 1

	# Keep this item in the array if both evaluate to true
	(money and date)
end

# Print the listings
apartments.uniq!.sort! { |a,b| a[3] <=> b[3] }
apartments.each do |apt|
	puts apt.join(", ")
end


