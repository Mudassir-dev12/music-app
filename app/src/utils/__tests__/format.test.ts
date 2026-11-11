import { formatRemaining, formatTime, getInitials } from '@/utils/format';

describe('format utilities', () => {
  it('formats elapsed time as m:ss', () => {
    expect(formatTime(0)).toBe('0:00');
    expect(formatTime(5)).toBe('0:05');
    expect(formatTime(65)).toBe('1:05');
    expect(formatTime(185.9)).toBe('3:05');
    expect(formatTime(-3)).toBe('0:00');
    expect(formatTime(null)).toBe('0:00');
  });

  it('formats negative remaining time as -m:ss', () => {
    expect(formatRemaining(0, 180)).toBe('-3:00');
    expect(formatRemaining(45, 180)).toBe('-2:15');
    expect(formatRemaining(200, 180)).toBe('-0:00');
    expect(formatRemaining(10, 0)).toBe('-0:00');
  });

  it('extracts user initials cleanly', () => {
    expect(getInitials('Jane Doe', 'jane@example.com')).toBe('JD');
    expect(getInitials(null, 'alex@example.com')).toBe('AE');
    expect(getInitials('alex', null)).toBe('AL');
  });
});
