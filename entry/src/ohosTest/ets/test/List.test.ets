import abilityTest from './Ability.test';
import fsrsSchedulerTest from './FsrsScheduler.test';
import performanceTest from './Performance.test';

export default function testsuite() {
  abilityTest();
  fsrsSchedulerTest();
  performanceTest();
}