require 'rubygems'
require 'mechanize'
require 'date'


APT_TYPES = [
	'Z000000001',	# 1/1
	'Z000000002',	# 2/1
	'Z000000005'	# 2/2
]

MOVEIN_DATE = Date.new(2013, 1, 3)


def getListings(a, date, apartmentType)
	# Grab the property search page
	results = nil
	a.get('http://property.onesite.realpage.com/ol/?s=1001107') do |page|
		# Submit the form
	    results = page.form_with(:name => 'Form1') do |search|
	    	#puts search.inspect
	        search['cfaSearchCriteria$cfaSearchCriteria$txtDateNeeded'] = date
	        search['cfaSearchCriteria$cfaSearchCriteria$lstApartmentTypes'] = apartmentType
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

APT_TYPES.each do |apt_type|
	apartments += getListings(M, '01/03/2013', apt_type)
end

# Filter out our listings
apartments.select! do |apt|
	money = (1600 > apt[3].delete("$").to_i) # Filter out apartments > $1600/mo
	begin
		available = Date.strptime(apt[1], "%m/%d/%Y")
	rescue
		available = Date.strptime(Date.today.to_s, "%Y-%m-%d")
	end
	date = (available <=> MOVEIN_DATE - 45) >= 0 and (available <=> MOVEIN_DATE + 14) <= 1 # Filter out apts not within a month's window
	(money and date)
end

# Print the listings
apartments.uniq!.sort! { |a,b| a[3] <=> b[3] }
apartments.each do |apt|
	puts apt.join(", ")
end


