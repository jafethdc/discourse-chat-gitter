import FilterRule from 'discourse/plugins/discourse-chat-gitter/discourse/models/filter-rule';
import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Component.extend({
  classNames: ['integration-item'],

  init(){
    this._super();
      this.set('editingFilter', FilterRule.create({}));
  },

  didInsertElement(){
    // debugger;
  },

  actions: {
    deleteFilter(filter){
      ajax('/gitter/filter_rules.json', {
        method: 'DELETE',
        data: filter.getProperties('category_id', 'filter', 'room', 'tags')
      }).then(()=>{
        this.get('integration.filters').removeObject(filter);
      }).catch(popupAjaxError);
    },

    saveFilter(){
      const data = Object.assign(this.get('editingFilter').getProperties('filter', 'category_id', 'tags'),
                                 this.get('integration').getProperties('room'));
      ajax('/gitter/filter_rules.json', {
        method: 'POST',
        data: data
      }).then(() => {
        this.get('integration.filters').pushObject(FilterRule.create(data));
        this.set('editingFilter', FilterRule.create({}));
      }).catch(popupAjaxError);
    }
  }
});
