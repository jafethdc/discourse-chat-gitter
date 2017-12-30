
Discourse::Application.routes.append do
  mount ::DiscourseGitter::Engine, at: '/gitter'
  get '/admin/plugins/gitter' => 'admin/plugins#index', constraints: StaffConstraint.new
  get '/gitter-transcript/:secret', to: :post_transcript, controller: 'discourse_gitter/public'
end
