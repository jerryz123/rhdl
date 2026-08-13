// Simulates both directions of a ready-valid interface adapter.
module interface_tb;
  typedef struct packed {
    logic valid;
    logic [7:0] bits;
  } forward_t;

  typedef struct packed {
    logic ready;
  } backward_t;

  forward_t ingress__producer_to_consumer;
  backward_t egress__consumer_to_producer;
  backward_t ingress__consumer_to_producer;
  forward_t egress__producer_to_consumer;

  ReadyValidAdapter8 dut (
    .ingress__producer_to_consumer(ingress__producer_to_consumer),
    .egress__consumer_to_producer(egress__consumer_to_producer),
    .ingress__consumer_to_producer(ingress__consumer_to_producer),
    .egress__producer_to_consumer(egress__producer_to_consumer)
  );

  initial begin
    ingress__producer_to_consumer = '{valid: 1'b1, bits: 8'hA5};
    egress__consumer_to_producer = '{ready: 1'b1};
    #1;

    if (egress__producer_to_consumer.valid !== 1'b1 ||
        egress__producer_to_consumer.bits !== 8'hA5)
      $fatal(1, "forward interface flow failed");
    if (ingress__consumer_to_producer.ready !== 1'b1)
      $fatal(1, "backward interface flow failed");

    $display("interface simulation passed");
    $finish;
  end
endmodule
