module IPD
	class Bookmark
	    attr_accessor :name, :url

	    def initialize()
	        @name = nil
	        @url = nil
	    end                            

        def to_s
            "#{@name} => #{@url}"                        
        end                        
	end

    class Bookmarks
        @@bookmarks = []
        @@current = nil
        def Bookmarks.bookmarks
            return @@bookmarks
        end
        def Bookmarks.handle_record(f_t, f_d)
            if f_t == 17 then # bookmark name
                bits = f_d[0..7]
                rest = f_d[8..-1]
#                puts "type of bookmark: #{bits[0]}"
                if bits[0] & 0x40 == 0x40 then 
                    rest = f_d[7..-1]
                end
                l_bn = rest[0..1].unpack('n')[0]
                s_bn = rest[2..1+l_bn]
#                puts "#{l_bn} => #{s_bn}"
                @@current = IPD::Bookmark.new()
                @@current.name = s_bn
                @@bookmarks.push @@current
            elsif f_t == 18 then # bookmark URL
                l_bn = f_d[0..1].unpack('n')[0]
                s_bu = f_d[2..1+l_bn]
                @@current.url = s_bu
            end
        end
    end
end
