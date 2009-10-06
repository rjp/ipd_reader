require 'ipd/bookmark'
require 'ipd/sms'
require 'ipd/mms'

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

        if "MMS Messages" == dbname then
            IPD::MMSList.handle_record(f_t, f_d)
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

#puts "BOOKMARKS:"
#puts IPD::Bookmarks.bookmarks
#puts "SMS:"
#puts IPD::SMSList.sms

fieldnames = {
0x01 => ['Bcc', 'EncodedStringValue'],
0x02 => ['Cc', 'EncodedStringValue'],
0x03 => ['Content-Location', 'UriValue'],
0x04 => ['Content-Type','ContentTypeValue'],
0x05 => ['Date', 'DateValue'],
0x06 => ['Delivery-Report', 'BooleanValue'],
0x07 => ['Delivery-Time', 'None'],
0x08 => ['Expiry', 'ExpiryValue'],
0x09 => ['From', 'FromValue'],
0x0a => ['Message-Class', 'MessageClassValue'],
0x0b => ['Message-ID', 'TextString'],
0x0c => ['Message-Type', 'MessageTypeValue'],
0x0d => ['MMS-Version', 'VersionValue'],
0x0e => ['Message-Size', 'LongInteger'],
0x0f => ['Priority', 'PriorityValue'],
0x10 => ['Read-Reply', 'BooleanValue'],
0x11 => ['Report-Allowed', 'BooleanValue'],
0x12 => ['Response-Status', 'ResponseStatusValue'],
0x13 => ['Response-Text', 'EncodedStringValue'],
0x14 => ['Sender-Visibility', 'SenderVisibilityValue'],
0x15 => ['Status', 'StatusValue'],
0x16 => ['Subject', 'EncodedStringValue'],
0x17 => ['To', 'EncodedStringValue'],
0x18 => ['Transaction-Id', 'TextString']
}

$mtypes = { 
0x80 => 'm-send-req',
0x81 => 'm-send-conf',
0x82 => 'm-notification-ind',
0x83 => 'm-notifyresp-ind',
0x84 => 'm-retrieve-conf',
0x85 => 'm-acknowledge-ind',
0x86 => 'm-delivery-ind'
}

def decode_MessageTypeValue(z)
    v, z = z.unpack('aa*')
    h = v[0]
    return $mtypes[h], z
end

def decode_TextString(z)
    v, z = z.unpack('Z*a*')
    return v, z
end

def decode_VersionValue(z)
    v, z = z.unpack('aa*')
    h = v[0]
    vr = 'unknown'
    if h & 0x80 then
        vr = ((h & 0x70) >> 4).to_s << '.' << (h & 0xf).to_s
    else
        vr, z = z.unpack('Z*a*')
    end
    return vr, z
end

def decode_EncodedStringValue(z)
    return decode_TextString(z)
end

def decode_MessageClassValue(z)
    v, z = z.unpack('aa*')
    t = { 0x80 => 'Personal', 0x81 => 'Advert', 0x82 => 'Informational', 0x83 => 'Auto' }
    return t[v[0]], z
end

def decode_PriorityValue(z)
    v, z = z.unpack('aa*')
    t = { 0x80 => 'Low', 0x81 => 'Normal', 0x82 => 'High' }
    return t[v[0]], z
end

def decode_BooleanValue(z)
    v, z = z.unpack('aa*')
    t = { 0x80 => 'Yes', 0x81 => 'No' }
    return t[v[0]], z
end

def decode_FromValue(z)
    v, z = z.unpack('aa*')
    if v[0] == 129 then
        return '<not inserted>', z
    end

    return decode_EncodedStringValue(z)
end

def decode_DateValue(z)
    v, z = z.unpack('aa*')
puts "date is #{v[0]} bytes"
    d, z = z.unpack("a#{v[0].to_s}a*")
    return Time.at(d.unpack('N')[0]), z
end

# TODO fix this up
def decode_ContentTypeValue(z)
    v, t, z = z.unpack('a3Z*a*')
    return t, z
end

def decode_UriValue(z)
    t, z = z.unpack('Z*a*')
    return t, z
end

a = IPD::MMSList.mms[0].content
while a.length > 0 do
    tag, a = a.unpack('aa*')
    si = tag[0] & 0x7F

    if x = fieldnames[si] then
        t, a = self.send("decode_#{x[1]}", a)
        puts "#{x[0]}, #{x[1]} => #{t}"
    end
end
