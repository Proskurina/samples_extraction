class Activity < ActiveRecord::Base
  validates :activity_type, :presence => true
  belongs_to :activity_type
  belongs_to :instrument
  belongs_to :kit

  has_many :steps
  has_many :step_types, :through => :activity_type
  belongs_to :asset_group

  def select_barcodes(barcodes)
    barcodes.each do |barcode|
      if asset_group.assets.select{|a| a.barcode == barcode}.empty?
        asset = Asset.find_by_barcode!(barcode)
        asset_group.assets << asset
      end
    end
  end

  def unselect_barcodes(barcodes)
    barcodes.each do |barcode|
      selection = asset_group.assets.select{|a| a.barcode == barcode}
      asset_group.assets.delete(selection)
    end
  end

  def assets
    steps.last.assets
  end

  def steps_for(assets)
    assets.map(&:steps).concat(steps).flatten.compact.uniq
  end

  def step_types_for(assets, required_assets=nil)
    step_types.select{|step_type| step_type.compatible_with?(assets, required_assets)}
  end

  def create_step(step_type)
    group = AssetGroup.create
    group.assets << asset_group.assets
    step = steps.create(:step_type => step_type, :asset_group_id => group.id)
  end

end