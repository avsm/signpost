module TacticSolver
  class Question
    include Bud
    include TacticProtocol

    bootstrap do
      need_truth <~ [[@solver, [@question, ip_port, @user_info, "user_question"]]]
    end

    bloom :question_answer do
      needed_truth_scratch <= needed_truth.payloads
    end

    def initialize options, &block
      @question = options.delete(:what)
      @solver = options.delete(:solver)
      @user_info = options.delete(:user_info)
      @callback = block
      @return_value = nil
      @working = true

      super options

      self.run_bg
      self.register_callback(:needed_truth_scratch) do |d|
        @return_value = @callback.call(d)
        @working = false
      end
    end

    def answer
      # Spin lock until the value is returned
      while @working do end

      # terminate the question
      self.stop

      # Returns what was returned by the 
      @return_value
    end
  end
end
