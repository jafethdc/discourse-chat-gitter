module Jobs
  class NotifyGitter < Jobs::Base
    def execute(args)
      DiscourseGitter::Gitter.notify(args[:post_id])
    end
  end
end
