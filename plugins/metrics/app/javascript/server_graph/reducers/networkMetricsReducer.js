import * as types from '../actions/actionTypes';
import initialState from './initialState';
import moment from 'moment';

const requestMetricsData = (state,{ requestedAt }) => {
  return Object.assign({}, state, {
    isFetching: true,
    requestedAt
  });
}

const requestMetricsDataFailure = (state) => {
  return Object.assign({}, state, {
    isFetching: false
  });
};

const prepareData = (rawData) => {
  var data = rawData.map( value => {
    // https://devhints.io/moment
    //console.log (moment.unix(value[0]).format('YYYY-MM-DD HH:mm:ss'));
    var obj = {
      x: moment.unix(value[0]).format('YYYY-MM-DD HH:mm:ss'),
      y: parseFloat(value[1])/100
    };
    return obj
  });

  return data
}

const receiveMetricsData = (state,{ metrics_data,instanceId,startTime,endTime,receivedAt,step }) => {
  var valuesTx = metrics_data.tx
  var valuesRx = metrics_data.rx;
  // prepare data for nivo line
  // https://nivo.rocks/line
  var dataTx = prepareData(valuesTx.values);
  var dataRx = prepareData(valuesRx.values);

  return Object.assign({},state,{
    data: [
      {
        data: dataTx,
        id: "Transmitted",
      },
      {
        data: dataRx,
        id: "Received",
      }
    ],
    startTime: startTime,
    endTime: endTime,
    step:step,
    instanceId: instanceId,
    isFetching: false,
    receivedAt
  });
}

// all reducers are called on each dispatch!
// switch to handle the correct action that was dispatched
export const networkMetrics = function(state = initialState.network, action) {
  console.log('network-metrics-reducers-switch');
  console.log(action);
  switch (action.type) {
    case types.RECEIVE_NETWORK_METRICS_DATA:
      return receiveMetricsData(state,action);
    case types.REQUEST_NETWORK_METRICS_DATA:
      return requestMetricsData(state,action);
    case types.REQUEST_NETWORK_METRICS_DATA_FAILURE:
      return requestMetricsDataFailure(state,action);

    // return new state
    default: return state;
  }
};
