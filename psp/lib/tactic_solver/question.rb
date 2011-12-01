module TacticSolver
  class Question
    include Bud
    include TacticProtocol

    bootstrap do
      need_truth <~ [[@solver, [@question, ip_port, "user_question"]]]
    end

    bloom :question_answer do
      needed_truth_scratch <= needed_truth.payloads
    end

    def initialize what, solver, &block
      @question = what
      @solver = solver
      @callback = block

      options = {}
      super options

      self.run_bg
      self.register_callback(:needed_truth_scratch) do |d|
        @callback.call(d)
      end
    end
  end
end
