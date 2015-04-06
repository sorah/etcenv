module Etcenv
  module Utils
    class << self
      def uniq_with_keeping_first_appearance(array)
        set = {}
        result = []
        array.each do |x|
          next if set[x]
          result.push x
          set[x] = true
        end
        result
      end
    end
  end
end
