import RestModel from 'discourse/models/rest';
import computed from "ember-addons/ember-computed-decorators";

export default RestModel.extend({
  room: '',
  webhook: '',
  room_id: '',

  init(){
    this._super();
    if(typeof this.get('filters') === 'undefined'){
      this.set('filters', []);
    }
  }
});
