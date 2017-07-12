import Integration from 'discourse/plugins/discourse-chat-gitter/discourse/models/integration';
import computed from "ember-addons/ember-computed-decorators";
import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend({
  filters: [
    { id: 'watch', name: I18n.t('gitter.future.watch'), icon: 'exclamation-circle' },
    { id: 'follow', name: I18n.t('gitter.future.follow'), icon: 'circle'},
    { id: 'mute', name: I18n.t('gitter.future.mute'), icon: 'times-circle' }
  ],

  editingIntegration: Integration.create({}),

  @computed('editingIntegration.room', 'editingIntegration.webhook')
  integrationSaveDisabled(room, webhook){
    return Ember.isEmpty(room) || Ember.isEmpty(webhook);
  },

  actions: {
    saveIntegration(){
      ajax('/gitter/integrations.json', {
        method: 'POST',
        data: this.get('editingIntegration').getProperties('room', 'room_id', 'webhook')
      }).then(() => {
        this.get('model').pushObject(this.get('editingIntegration'));
        this.set('editingIntegration', Integration.create({}));
      }).catch(popupAjaxError);
    },

    deleteIntegration(integration){
      ajax('/gitter/integrations.json', {
        method: 'DELETE',
        data: integration.getProperties('room')
      }).then(() => {
        this.get('model').removeObject(integration);
      }).catch(popupAjaxError);
    }
  }
});
