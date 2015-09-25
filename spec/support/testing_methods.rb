def test_concurrency_of(pool)
  baseline = Time.now.to_f
  values = 10.times.map { pool.future.sleepy_work }.map(&:value)
  values.select { |t| t - baseline < 0.1 }.length
end
