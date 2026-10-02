import abilityTest from './Ability.test';
import fsrsSchedulerTest from './FsrsScheduler.test';
import performanceTest from './Performance.test';
import m2ExitCheck from './M2ExitCheck.test';

export default function testsuite() {
  abilityTest();
  fsrsSchedulerTest();
  performanceTest();
  m2ExitCheck();
}