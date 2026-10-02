import { TodayPage } from '../ui/pages/TodayPage';

@Entry
@Component
struct Index {
  build() {
    Column() {
      TodayPage()
    }
    .width('100%')
    .height('100%')
  }
}