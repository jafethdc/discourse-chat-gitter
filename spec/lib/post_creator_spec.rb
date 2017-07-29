require 'rails_helper'

RSpec.describe PostCreator do
  let(:first_post) { Fabricate(:post) }
  let(:topic) { Fabricate(:topic, posts: [first_post]) }

  before do
    SiteSetting.queue_jobs = true
    Jobs::NotifyGitter.jobs.clear
  end

  describe 'when a post is created' do
    describe 'when plugin is enabled' do
      before do
        SiteSetting.gitter_enabled = true
      end

      it 'schedules a job for gitter post' do
        freeze_time do
          post = PostCreator.new(topic.user, raw: 'this is a reply. yep it is.', topic_id: topic.id).create!
          job = Jobs::NotifyGitter.jobs.last
          expected_time = (Time.zone.now + SiteSetting.gitter_notification_delay.seconds).to_f

          expect(job['at']).to eq(expected_time)
          expect(job['args'].first['post_id']).to eq(post.id)
        end
      end
    end

    describe 'when plugin is not enabled' do
      before do
        SiteSetting.gitter_enabled = false
      end

      it 'should not schedule a job for slack post' do
        PostCreator.new(topic.user, raw: 'this is not a reply. nope its not', topic_id: topic.id).create!
        expect(Jobs::NotifyGitter.jobs).to be_empty
      end
    end
  end
end
