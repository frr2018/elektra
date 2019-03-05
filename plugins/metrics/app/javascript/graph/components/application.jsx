import { HashRouter, Route, Redirect } from 'react-router-dom'
import Tabs from './tabs';

import cpuMetrics from '../containers/cpuMetricsContainer'
// containers: react component thats uses the store and supply props to the child components

const tabsConfig = [
  { to: '/cpu', label: 'CPU Usage', component: cpuMetrics }
]

// render all components inside a hash router
export default (props) =>
  <HashRouter /*hashType="noslash"*/ >
    <div>
      <Route exact path="/" render={ () => <Redirect to="/cpu"/>}/>
      <Route path="/:activeTab" children={ ({match, location, history}) =>
        React.createElement(Tabs, Object.assign({}, {match, location, history, tabsConfig}, props))
      }/>
    </div>
  </HashRouter>
