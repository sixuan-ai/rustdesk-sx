import unittest

from sample_stream_tcp import parse_ss


class TcpCounterTests(unittest.TestCase):
    def test_cumulative_retransmission_and_rtt_are_not_inflight_or_variation(self):
        sample = ('0 0 [::ffff:100.64.0.1]:21118 [::ffff:100.64.0.2]:32000\n'
                  '\t cubic rtt:44.837/4.467 mss:1228 cwnd:10 '
                  'bytes_sent:900000 bytes_acked:700000 bytes_retrans:170326 '
                  'retrans:0/140\n')
        row, = parse_ss(sample)
        self.assertEqual(row['total_retrans'], 140)
        self.assertEqual(row['retrans_out'], 0)
        self.assertEqual(row['rtt_ms'], 44.837)
        self.assertEqual(row['bytes_acked'], 700000)
        self.assertNotIn('100.64', str(row))

    def test_connection_changes_are_distinct_and_missing_counters_stay_unknown(self):
        first, second = parse_ss('0 0 host:21118 peer:32000\n\t cubic cwnd:10\n'
                                 '0 0 host:21118 peer:32001\n\t cubic cwnd:4\n')
        self.assertNotEqual(first['socket_id'], second['socket_id'])
        self.assertNotIn('bytes_acked', first)


if __name__ == '__main__':
    unittest.main()
