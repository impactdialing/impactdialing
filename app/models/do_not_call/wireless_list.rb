module DoNotCall
  class WirelessList
    attr_reader :block_list, :wireless_port_list, :landline_port_list

    def initialize
      @block_list = WirelessBlockList
      @wireless_port_list = PortList.new(:wireless)
      @landline_port_list = PortList.new(:landline)
    end

    def prohibits?(phone_number)
      return false if phone_number.blank?
      
      if not_wireless_block?(phone_number)
        # Number does not match wireless block pattern
        # so it is a landline unless it was ported.
        return ported_to_wireless?(phone_number)
      end
      # It is in the wireless block.
      # So if it has not been ported to a landline
      # then it is wireless and prohibited.
      return not_ported_to_landline?(phone_number)
    end

    def not_wireless_block?(phone_number)
      return ( not block_list.exists?(phone_number[-10,-1]) )
    end

    def ported_to_wireless?(phone_number)
      return wireless_port_list.exists?(phone_number)
    end

    def not_ported_to_landline?(phone_number)
      return (not landline_port_list.exists?(phone_number) )
    end
  end
end