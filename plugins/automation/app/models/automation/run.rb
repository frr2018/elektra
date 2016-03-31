require 'active_resource'

module Automation

  class Run < ::Automation::BaseAutomation
    self.collection_name = "runs"

    def duration
      time_diff = self.updated_at.to_time - self.created_at.to_time
      Time.at(time_diff.to_i.abs).utc.strftime "%H:%M:%S"
    end

    def state_to_string
      case self.state
        when State::Run::PREPARING then "Preparing"
        when State::Run::EXECUTING then "Executing"
        when State::Run::FAILED then "Failed"
        when State::Run::COMPLETED then "Completed"
        else
          State::MISSING
      end
    end

  end

end
