class ActivitiesController < ApplicationController
  before_action :set_activity, only: [:show, :update, :step_types_active, :steps_finished, :steps_finished_with_operations]
  before_action :select_assets, only: [:show, :update, :step_types_active, :steps_finished, :steps_finished_with_operations]
  before_action :select_assets_grouped, only: [:show, :update, :step_types_active, :steps_finished, :steps_finished_with_operations]

  before_action :set_kit, only: [:create]
  before_action :set_instrument, only: [:create]

  before_action :set_user, only: [:update]

  before_action :set_uploaded_files, only: [:update]
  #before_action :set_params_for_step_in_progress, only: [:update]

  before_action :set_activity_type, only: [:create_without_kit]

  #before_filter :session_authenticate, only: [:update, :create]

  def session_authenticate
    raise ActionController::InvalidAuthenticityToken unless session[:session_id]
  end

  def update
    select_assets
    select_assets_grouped

    @activity.finish unless params[:finish].nil?
    @step_types = @activity.step_types_for(@assets)
    @steps = @activity.previous_steps

    respond_to do |format|
      format.html { render :show }
      format.json { render :show, status: :created, location: @activity }
    end
  end


  def show
    @assets = @activity.asset_group.assets
    @step_types = @activity.step_types_for(@assets)
    @steps = @activity.previous_steps

    respond_to do |format|
      format.html { render :show }
      format.json { render :show, status: :created, location: @activity }
    end
  end

  def index
  end


  def finished
    @in_steps_finished = true
    @steps = @activity.previous_steps

    respond_to do |format|
      format.html {
        render 'steps/_finished', :locals => {
          :steps => @steps,
          :activity => @activity,
        }, :layout => false
      }
    end
  end

  def finished_with_operations
    @steps = @activity.previous_steps

    respond_to do |format|
      format.html {
        render 'steps/_finished', :locals => {
          :steps => @steps,
          :activity => @activity,
          :selected_step_id => params[:step_id]
        }, :layout => false
      }
    end
  end


  def create_without_kit
    @asset_group = AssetGroup.create
    @activity = @activity_type.activities.create(
      :instrument =>nil,
      :activity_type => @activity_type,
      :asset_group => @asset_group,
      :kit => nil)

    respond_to do |format|
      if @activity.save
        format.html { redirect_to @activity, notice: 'Activity was successfully created.' }
        format.json { render :show, status: :created, location: @activity }
      else
        format.html { render :new }
        format.json { render json: @activity.errors, status: :unprocessable_entity }
      end
    end
  end

  def create
    @asset_group = AssetGroup.create
    @activity_type = @kit.kit_type.activity_type
    @activity = @activity_type.activities.create(
      :instrument => @instrument,
      :activity_type => @activity_type,
      :asset_group => @asset_group,
      :kit => @kit)

    respond_to do |format|
      if @activity.save
        format.html { redirect_to @activity, notice: 'Activity was successfully created.' }
        format.json { render :show, status: :created, location: @activity }
      else
        format.html { render :new }
        format.json { render json: @activity.errors, status: :unprocessable_entity }
      end
    end
  end

  private

    def set_user
      @user = @current_user
      if @user.nil?
        flash[:danger] = 'User not found'
        redirect_to :back
      end
    end

    def set_kit
      @kit = Kit.find_by_barcode!(params[:kit_barcode])
    rescue ActiveRecord::RecordNotFound => e
      flash[:danger] = 'Kit not found'
      redirect_to :back
    end

    def set_activity_type
      @activity_type = ActivityType.find_by_id(params[:activity_type_id])
    rescue ActiveRecord::RecordNotFound => e
      flash[:danger] = 'Activity Type not found'
      redirect_to :back
    end

    def set_instrument
      @instrument = Instrument.find_by_barcode!(params[:instrument_barcode])
      unless @instrument.compatible_with_kit?(@kit)
        flash[:danger] = "Instrument not compatible with kit type '#{@kit.kit_type.name}'"
        redirect_to :back
      end
    rescue RecordNotFound => e
      flash[:danger] = 'Instrument not found'
      redirect_back
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_activity
      @activity = Activity.find(params[:id])
      @asset_group = @activity.asset_group
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def activity_params
      params.require(:activity).permit(:kit_barcode, :asset_barcode, :step_type, :instrument_barcode, :delete_barcode)
    end


  def select_assets
    @assets = @activity.asset_group.assets.includes(:facts)

  end

  def select_assets_grouped
    @assets_grouped = assets_by_fact_group
  end

  def set_uploaded_files
    @upload_ids = []
    if params[:upload_ids]
      @upload_ids = JSON.parse(params[:upload_ids])
    end
  end

  def clean_fact_group(groups)
    h = {}
    groups.each do |group, assets|
      h[group] = assets.uniq
    end
    h
  end

  def assets_by_fact_group
    return [] unless @assets
    obj_type = Struct.new(:predicate,:object, :to_add_by, :to_remove_by, :object_asset_id)
    groups = @assets.group_by do |a|
      a.facts.sort do |f1,f2|
        # Canonical sort of facts
        if f1.predicate == f2.predicate
          obj1 = f1.object
          obj1 =  '?' unless f1["object_asset_id"].nil?
          obj2 = f1.object
          obj2 =  '?' unless f2["object_asset_id"].nil?
          (obj1 <=> obj2)
        else
          f1.predicate <=> f2.predicate
        end
      end.map(&:as_json).map do |f|
        obj = f["object"]
        if f["object_asset_id"]
          obj="?"
        end
        obj_type.new(f["predicate"], obj, f["to_add_by"], f["to_remove_by"], nil)
      end.uniq
    end
    clean_fact_group(groups)
  end



end
