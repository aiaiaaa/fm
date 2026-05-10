import backgroundTaskManager from '@ohos.resourceschedule.backgroundTaskManager';
import wantAgent from '@ohos.app.ability.wantAgent';
import common from '@ohos.app.ability.common';
import hilog from '@ohos.hilog';

const TAG = 'BackgroundTask';

/**
 * 申请音频播放的长时任务（long-running task），让应用切到后台仍能继续播放。
 * 需要权限 ohos.permission.KEEP_BACKGROUND_RUNNING
 */
export class BackgroundTask {
  static async start(context: common.UIAbilityContext): Promise<void> {
    try {
      const agentInfo: wantAgent.WantAgentInfo = {
        wants: [{
          bundleName: context.abilityInfo.bundleName,
          abilityName: context.abilityInfo.name
        }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const agent = await wantAgent.getWantAgent(agentInfo);
      await backgroundTaskManager.startBackgroundRunning(
        context,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK,
        agent
      );
      hilog.info(0x0000, TAG, 'background task started');
    } catch (e) {
      hilog.error(0x0000, TAG, `startBackgroundRunning failed: ${JSON.stringify(e)}`);
    }
  }

  static async stop(context: common.UIAbilityContext): Promise<void> {
    try {
      await backgroundTaskManager.stopBackgroundRunning(context);
      hilog.info(0x0000, TAG, 'background task stopped');
    } catch (e) {
      hilog.error(0x0000, TAG, `stopBackgroundRunning failed: ${JSON.stringify(e)}`);
    }
  }
}
