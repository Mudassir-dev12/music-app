import type { Track } from '@/api/types';
import {
  clearPlayNext,
  cycleRepeat,
  enqueueLast,
  enqueueNext,
  getCurrentTrack,
  getUpNext,
  INITIAL_QUEUE_STATE,
  move,
  movePlayNext,
  next,
  playList,
  previous,
  removeAt,
  removePlayNextAt,
  toggleShuffle,
} from '@/player/queue';

function makeTrack(id: string): Track {
  return {
    video_id: id,
    title: `Song ${id}`,
    artists: [{ id: null, name: `Artist ${id}` }],
    artist: `Artist ${id}`,
    album: null,
    album_id: null,
    duration_seconds: 180,
    thumbnail: null,
    is_explicit: false,
  };
}

const T1 = makeTrack('t1');
const T2 = makeTrack('t2');
const T3 = makeTrack('t3');
const T4 = makeTrack('t4');
const TX = makeTrack('tx');
const TY = makeTrack('ty');

describe('queue pure logic', () => {
  it('playList initializes queue at startIndex', () => {
    const s = playList(INITIAL_QUEUE_STATE, [T1, T2, T3], 1);
    expect(getCurrentTrack(s)?.video_id).toBe('t2');
    expect(getUpNext(s).map((t) => t.video_id)).toEqual(['t3']);
  });

  it('enqueueNext and enqueueLast insert into playNext and drain before Up Next', () => {
    let s = playList(INITIAL_QUEUE_STATE, [T1, T2, T3], 0);
    s = enqueueLast(s, TY);
    s = enqueueNext(s, TX);
    expect(s.playNext.map((t) => t.video_id)).toEqual(['tx', 'ty']);

    const r1 = next(s);
    expect(r1.track?.video_id).toBe('tx');
    expect(r1.shouldPlay).toBe(true);
    expect(getUpNext(r1.state).map((t) => t.video_id)).toEqual(['t2', 't3']);

    const r2 = next(r1.state);
    expect(r2.track?.video_id).toBe('ty');

    const r3 = next(r2.state);
    expect(r3.track?.video_id).toBe('t2');
    expect(getUpNext(r3.state).map((t) => t.video_id)).toEqual(['t3']);
  });

  it('previous restarts when > 3s and goes back when <= 3s', () => {
    const s0 = playList(INITIAL_QUEUE_STATE, [T1, T2, T3], 0);
    const s1 = next(s0).state;
    expect(getCurrentTrack(s1)?.video_id).toBe('t2');

    const restart = previous(s1, 4.2);
    expect(restart.track?.video_id).toBe('t2');
    expect(restart.seekToStart).toBe(true);

    const back = previous(s1, 1.5);
    expect(back.track?.video_id).toBe('t1');
    expect(back.seekToStart).toBeUndefined();
  });

  it('repeat modes: off stops at first track paused, all wraps, one replays on track end', () => {
    let s = playList(INITIAL_QUEUE_STATE, [T1, T2], 1);
    // Repeat off at end
    const endOff = next(s, true);
    expect(endOff.track?.video_id).toBe('t1');
    expect(endOff.shouldPlay).toBe(false);

    // Repeat all wraps
    s = cycleRepeat(s);
    expect(s.repeat).toBe('all');
    const endAll = next(s, true);
    expect(endAll.track?.video_id).toBe('t1');
    expect(endAll.shouldPlay).toBe(true);

    // Repeat one replays current on track end
    s = cycleRepeat(s);
    expect(s.repeat).toBe('one');
    const endOne = next(s, true);
    expect(endOne.track?.video_id).toBe('t2');
    expect(endOne.replayCurrent).toBe(true);
    expect(endOne.shouldPlay).toBe(true);

    // Cycle back to off
    expect(cycleRepeat(s).repeat).toBe('off');
  });

  it('toggleShuffle keeps current track first and restores original order', () => {
    const s0 = playList(INITIAL_QUEUE_STATE, [T1, T2, T3, T4], 2); // current is T3
    const shuffled = toggleShuffle(s0, () => 0);
    expect(shuffled.shuffle).toBe(true);
    expect(shuffled.queue[0].video_id).toBe('t3');
    expect(shuffled.currentIndex).toBe(0);
    expect(shuffled.queue).toHaveLength(4);

    // Advance to another track then unshuffle
    const stepped = next(shuffled).state;
    const currentAfterStep = getCurrentTrack(stepped)!;
    const unshuffled = toggleShuffle(stepped);
    expect(unshuffled.shuffle).toBe(false);
    expect(unshuffled.queue.map((t) => t.video_id)).toEqual(['t1', 't2', 't3', 't4']);
    expect(getCurrentTrack(unshuffled)?.video_id).toBe(currentAfterStep.video_id);
  });

  it('removeAt handles removing before and at currentIndex', () => {
    const s0 = playList(INITIAL_QUEUE_STATE, [T1, T2, T3], 1); // current T2
    const afterRemoveBefore = removeAt(s0, 0);
    expect(afterRemoveBefore.queue.map((t) => t.video_id)).toEqual(['t2', 't3']);
    expect(getCurrentTrack(afterRemoveBefore)?.video_id).toBe('t2');
    expect(afterRemoveBefore.currentIndex).toBe(0);

    const afterRemoveCurrent = removeAt(afterRemoveBefore, 0);
    expect(afterRemoveCurrent.queue.map((t) => t.video_id)).toEqual(['t3']);
    expect(getCurrentTrack(afterRemoveCurrent)?.video_id).toBe('t3');

    const empty = removeAt(afterRemoveCurrent, 0);
    expect(empty.queue).toEqual([]);
    expect(empty.currentIndex).toBe(-1);
  });

  it('move updates queue order and preserves current track', () => {
    const s0 = playList(INITIAL_QUEUE_STATE, [T1, T2, T3, T4], 1); // current T2
    const moved = move(s0, 1, 3);
    expect(moved.queue.map((t) => t.video_id)).toEqual(['t1', 't3', 't4', 't2']);
    expect(getCurrentTrack(moved)?.video_id).toBe('t2');
    expect(moved.currentIndex).toBe(3);

    const movedBack = move(moved, 2, 0);
    expect(movedBack.queue.map((t) => t.video_id)).toEqual(['t4', 't1', 't3', 't2']);
  });

  it('playNext helpers remove, reorder, and clear', () => {
    let s = playList(INITIAL_QUEUE_STATE, [T1], 0);
    s = enqueueLast(s, T2);
    s = enqueueLast(s, T3);
    s = movePlayNext(s, 0, 1);
    expect(s.playNext.map((t) => t.video_id)).toEqual(['t3', 't2']);
    s = removePlayNextAt(s, 0);
    expect(s.playNext.map((t) => t.video_id)).toEqual(['t2']);
    s = clearPlayNext(s);
    expect(s.playNext).toEqual([]);
  });
});
