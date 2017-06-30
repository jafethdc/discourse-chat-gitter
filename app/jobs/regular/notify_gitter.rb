module Jobs
  class NotifyGitter < Jobs::Base
    def execute(args)
      puts("FROM NOTIFY GITTER BITCH #{args[:post_id]}")
      DiscourseGitter::Gitter.notify(args[:post_id])
    end
  end
end
