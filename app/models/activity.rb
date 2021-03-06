require 'date'

class Activity < ActiveRecord::Base
  validates :activity_type, :presence => true
  validates :asset_group, :presence => true
  belongs_to :activity_type
  belongs_to :instrument
  belongs_to :kit

  has_many :steps
  has_many :step_types, :through => :activity_type

  has_many :uploads

  belongs_to :asset_group

  has_many :users, :through => :steps

  scope :for_assets, ->(assets) { joins(:asset_group => :assets).where(:asset_group => {
    :asset_groups_assets=> {:asset_id => assets }
    })
  }

  scope :for_activity_type, ->(activity_type) {
    where(:activity_type => activity_type)
  }


  class StepWithoutInputs < StandardError
  end

  scope :in_progress, ->() { where('completed_at is null')}
  scope :finished, ->() { where('completed_at is not null')}

  def last_user
    users.last
  end

  def finish
    update_attributes(:completed_at => DateTime.now)
  end

  def finished?
    !completed_at.nil?
  end

  def previous_steps
    asset_group.assets.includes(:steps).map(&:steps).concat(steps).flatten.sort{|a,b| a.created_at <=> b.created_at}.uniq
  end

  def assets
    steps.last.assets
  end

  def steps_for(assets)
    assets.includes(:steps).map(&:steps).concat(steps).flatten.compact.uniq
  end

  def step_types_for(assets, required_assets=nil)
    stypes = step_types.includes(:condition_groups => :conditions).select do |step_type|
      step_type.compatible_with?(assets, required_assets)
    end
    stype = stypes.detect{|stype| steps.in_progress.for_step_type(stype).count > 0}
    stype.nil? ? stypes : [stype]
  end

  def step_types_active
    step_types_for(asset_group.assets)
  end

  def perform_step_actions_for(id, obj, step_type, step_params)
    if step_params[:data_action_type] == id
      params = step_params[:file] ? {:file => step_params[:file] } : JSON.parse(step_params[:data_params])
      value = obj.send(step_params[:data_action], step_type, params)
    end
  end

  def params_for_create_and_complete_the_step?(step_params)
     (step_params.nil? || step_params[:state].nil? || step_params[:state] == 'done')
  end

  def params_for_progress_with_step?(step_params)
    # || (step_params[:data_params]!='{}')))
    (!step_params.nil? &&
      ((step_params[:state]!='done' && step_params[:data_action_type]=='progress_step')))
  end

  def params_for_finish_step?(step_params)
    !params_for_progress_with_step?(step_params)
  end

  include Lab::Actions

  def step(step_type, user, step_params)
    perform_step_actions_for('before_step', self, step_type, step_params)

    step = steps.in_progress.for_step_type(step_type).first
    if (step.nil? && params_for_create_and_complete_the_step?(step_params))
      return steps.create!(:step_type => step_type, :asset_group_id => asset_group.id,
        :user_id => user.id)
    end
    if params_for_progress_with_step?(step_params)
      unless step
        group = AssetGroup.create!
        step = steps.create!(:step_type => step_type, :asset_group_id => group.id,
          :user_id => user.id, :in_progress? => true)
      end
      perform_step_actions_for('progress_step', step, step_type, step_params)
    else
      if step && params_for_finish_step?(step_params)
        step.finish
      else
        raise StepWithoutInputs
      end
    end
    step
  end

  def reasoning_step_types_for(assets)
    step_types.for_reasoning.select do |s|
      s.compatible_with?(assets)
    end
  end

  def reasoning!
    PushDataJob.perform_later
  end

end
