import { connect } from  'react-redux';
import RestVolumeStatusModal from '../../components/volumes/extend_size';
import {submitExtendVolumeSizeForm,fetchVolume} from '../../actions/volumes';

export default connect(
  (state,ownProps ) => {
    let volume;
    let id = ownProps.match && ownProps.match.params && ownProps.match.params.id

    if (id) {
      volume = state.volumes.items.find(item => item.id == id)
    }
    return { volume, id }
  },
  (dispatch,ownProps) => {
    let id = ownProps.match && ownProps.match.params && ownProps.match.params.id
    return {
      handleSubmit: (values) => id ? dispatch(submitExtendVolumeSizeForm(id,values)) : null,
      loadVolume: () => id ? dispatch(fetchVolume(id)) : null
    }
  }
)(RestVolumeStatusModal);
