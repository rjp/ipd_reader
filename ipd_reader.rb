require 'ipd/bookmark'
require 'ipd/sms'

identifier = 'Inter@ctive Pager Backup/Restore File'

ipd = File.new(ARGV[0])
check = ipd.sysread(identifier.length + 1)

if identifier + "\n" != check then
	puts "not an ipd file?"
	exit 1
end

# ok, now we have an IPD file
version = ipd.sysread(1)

if version[0] != 2 then
	puts "we only know about version 2 files, this is v#{version[0]}"
	exit 2
end

database_count = ipd.sysread(2).unpack('n')[0]
puts "there are #{database_count} databases in this file"

zero = ipd.sysread(1)

databases = []
1.upto(database_count) do |i|
	dnl = ipd.sysread(2).unpack('S')[0] # why S here but n up there?
	dn = ipd.sysread(dnl-1)
	zero = ipd.sysread(1) # discard the null
	databases.push dn
end

def get_network_four(x)
	a = x.sysread(2).unpack('S')[0]
	b = x.sysread(2).unpack('S')[0]
	return a + b*65536
end

mms = 0
begin
loop do
	pos = ipd.sysread(2).unpack('S')[0]
	db_l = get_network_four(ipd).to_i
	data = ipd.sysread(db_l)
	db_v, db_rh, db_id, fields = data.unpack('CSLa*')
	if pos == 26 then
#	puts "block is [#{pos}] = #{databases[pos]}, length=#{db_l}, version=#{db_v} id=#{db_id}"
	end
    dbname = databases[pos]

    s_bn = ''
	while fields.length > 0 do
		f_l, f_t, fields = fields.unpack('SCa*')
		f_d, fields = fields.unpack("a#{f_l}a*")

        if "Browser Bookmarks" == dbname then
            IPD::Bookmarks.handle_record(f_t, f_d)
        end

        if "SMS Messages" == dbname then
            IPD::SMSList.handle_record(f_t, f_d)
        end

		if pos == 1 then
			if f_t == 105 then
				mms_file = mms_file || File.open("mms_#{mms}", 'w')
				mms_file.syswrite(f_d)
			else
				mms_file = nil
			end
			mms = mms + 1
		end
	end	
end
rescue => e
    puts e
end

puts "BOOKMARKS:"
puts IPD::Bookmarks.bookmarks

puts "SMS:"
puts IPD::SMSList.sms
