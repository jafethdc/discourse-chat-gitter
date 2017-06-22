
export default Ember.Controller.extend({
  filters: [
    { id: 'watch', name: I18n.t('gitter.future.watch'), icon: 'exclamation-circle' },
    { id: 'follow', name: I18n.t('gitter.future.follow'), icon: 'circle'},
    { id: 'mute', name: I18n.t('gitter.future.mute'), icon: 'times-circle' }
  ],

  actions: {
    delete(filter){
      console.log('filter');
      console.log(filter);
    }
  }
});
