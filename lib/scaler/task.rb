module Scaler
  class Task
    attr_reader :id
    attr_reader :state

    def initialize(id, connector)
      @id = id
      @connector = connector
      @state = nil
    end

    def update_state
      @state = @connector.fetch_task_state(@id)
    end

    def result
      @result ||= @connector.fetch_task_result(@id)
    end
  end
end
