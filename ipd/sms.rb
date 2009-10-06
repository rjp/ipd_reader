module IPD
	class SMS
	    attr_accessor :to, :date, :content, :direction, :other_date, :category

	    def initialize()
	        @to = nil
	        @date = nil
	        @other_date = nil
            @content = nil
            @direction = nil
            @category = nil
	    end                            

        def tag
            if @category == 5 then
                return 'MSC'
            else
                return @direction == 0 ? 'To' : 'From'
            end
        end

        def to_s
            "#{self.tag} #{@to} at #{@date}/#{other_date}\n=> ``#{@content}''"
        end                        
	end

    class SMSList
        @@sms = []
        @@current = nil
        def SMSList.sms
            return @@sms
        end
        def SMSList.handle_record(f_t, f_d)
            if ENV['DEBUG_SMS'] then
                $stderr.puts "SMS #{f_t} #{f_d.inspect}"
            end

            case f_t
            when 1
                @@current = IPD::SMS.new
                @@sms.push @@current
                @@current.date = Time.at(f_d[13..20].unpack('Q')[0]/1000)
                @@current.other_date = Time.at(f_d[21..28].unpack('Q')[0]/1000)
            when 11
                a, b = f_d.unpack('S2')
                @@current.direction = a
                @@current.category = b
            when 2
                to = f_d.unpack('a*')[0].gsub(/[^[:print:]]/, '')
                @@current.to = to
            when 4
                @@current.content = f_d.unpack('a*')[0].gsub(/[^[:print:]]/, '')
            end
        end
    end
end
