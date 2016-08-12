module Parsers
  class Symphony
    attr_reader :doc
    def initialize(str)
      @doc = Nokogiri::XML(str)
    end

    def self.valid_for?(str)
      return Nokogiri::XML(str).xpath("Rack").count == 1
    end

    def to_assets
      @doc.xpath("/Rack//RackPosition").map do |rack_position|
        facts = ["SampleId", "PositionName", "TotalVolumeInUl"].map do |name|
          value = rack_position.at_xpath(name).text
          if name == "PositionName"
            value = value.gsub!(':','')
          end
          Fact.new(:predicate => 'Symphony#'+name,
            :object => value
            )
        end
        asset = Asset.create!
        asset.facts << facts
        asset
      end
    end

    def add_assets(asset)
      to_assets.each do |a|
        asset.facts << Fact.create(:predicate => "Symphony:RackPosition", :object_asset_id => a.id)
      end
      asset.reasoning!
    end
  end
end


#a=Asset.first
#a.facts << Fact.create(:predicate => "")
#a=Asset.first
#parser = Parsers::Symphony.new("/Users/emr/RackFile_dna29mar2016b.xml")
#a.facts << parser.to_facts
