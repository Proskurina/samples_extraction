class AssetGroupsController < ApplicationController
  before_action :set_asset_group, only: [:show, :update, :print]
  before_action :set_activity, only: [:show, :update]
  before_action :update_barcodes, only: [:update]


  def show

    @assets = @asset_group.assets

    @assets_grouped = assets_by_fact_group

    @step_types = @activity.step_types_active

    respond_to do |format|
      format.html { render @asset_group }
      format.json { render :show, status: :created, location: [@activity, @asset_group] }
    end
  end


  def update
    @assets = @asset_group.assets
    @assets_grouped = assets_by_fact_group
    @step_types = @activity.step_types_active

    respond_to do |format|
      format.html { render @asset_group }
      format.json { render :update, status: :created, location: [@activity, @asset_group] }
    end
  end

  def print
    @asset_group.print(@current_user.printer_config)

    redirect_to :back
  end

  private

    def update_barcodes
      perform_barcode_removal
      perform_barcode_addition
    end

    def assets_by_fact_group
      obj_type = Struct.new(:predicate,:object,:to_add_by, :to_remove_by, :object_asset_id)
      @assets.group_by do |a|
        a.facts.map(&:as_json).map do |f|
          obj_type.new(f["predicate"], f["object"])
        end
      end
    end


    def set_activity

      # I need the activity to be able to know the step_types compatible to show.
      @activity = Activity.find(params_asset_group[:activity_id])
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_asset_group

      @asset_group = AssetGroup.find(params_asset_group[:id])
    end

  def perform_barcode_removal
    unless params_update_asset_group[:delete_barcode].empty?
      @asset_group.unselect_barcodes([params_update_asset_group[:delete_barcode]])
    end
  end

  def show_alert(data)
    @alerts = [] unless @alerts
    @alerts.push(data)
  end

  def perform_barcode_addition
    unless params_update_asset_group[:add_barcode].empty?
      barcodes = [params_update_asset_group[:add_barcode]]
      barcodes_str = "'"+barcodes.join(',')+"'";
      begin
        if @asset_group.select_barcodes(barcodes)
          show_alert({:type => 'info',
            :msg => "Barcode #{barcodes_str} added"})
        else
          show_alert({:type => 'warning',
            :msg => "Cannot select #{barcodes_str}"})
          #flash[:danger] = "Could not find barcodes #{barcodes}"
        end
      rescue Net::ReadTimeout => e
        show_alert({:type => 'danger',
          :msg => "Cannot connect with Sequencescape for reading barcode #{barcodes_str}"})
      rescue Sequencescape::Api::ResourceNotFound => e
        show_alert({:type => 'warning',
          :msg => "Cannot find barcode #{barcodes_str} in Sequencescape"})
      rescue StandardError => e
        show_alert({:type => 'danger',
          :msg => "Cannot connect with Sequencescape: Message: #{e.message}"})
      end
    end
  end

  def params_update_asset_group
    params.require(:asset_group).permit(:add_barcode, :delete_barcode)
  end

  def params_asset_group
    params.permit(:activity_id, :id, :add_barcode, :delete_barcode)
  end

end
