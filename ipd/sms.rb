module IPD
	class SMS
	    attr_accessor :to, :date, :content, :direction

	    def initialize()
	        @to = nil
	        @date = nil
            @content = nil
            @direction = nil
	    end                            

        def to_s
            "#{@direction == 0 ? 'To' : 'From'} #{@to} at #{@date} => ``#{@content}''"                        
        end                        
	end

    class SMSList
        @@sms = []
        @@current = nil
        def SMSList.sms
            return @@sms
        end
        def SMSList.handle_record(f_t, f_d)
            case f_t
            when 1
                @@current = IPD::SMS.new
                @@sms.push @@current
                @@current.date = Time.at(f_d[13..20].unpack('Q')[0]/1000)
            when 11
                a, b = f_d.unpack('S2')
                @@current.direction = a
            when 2
                to = f_d.unpack('a*')[0].gsub('\0', '')
                @@current.to = to
            when 4
                @@current.content = f_d.unpack('a*')[0]
            end
        end
    end
end
