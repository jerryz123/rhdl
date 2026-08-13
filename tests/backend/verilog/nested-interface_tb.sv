// Simulates both directions of a recursively nested interface adapter.
module nested_interface_tb;
  typedef struct packed {
    logic valid;
    logic [7:0] bits;
  } command_forward_t;

  typedef struct packed {
    logic ready;
  } command_backward_t;

  typedef struct packed {
    command_forward_t command;
    logic enable;
    command_backward_t response;
  } control_forward_t;

  typedef struct packed {
    command_backward_t command;
    command_forward_t response;
    logic [7:0] status;
  } control_backward_t;

  control_forward_t ingress__manager_to_device;
  control_backward_t egress__device_to_manager;
  control_backward_t ingress__device_to_manager;
  control_forward_t egress__manager_to_device;

  NestedInterfaceAdapter dut (
    .ingress__manager_to_device(ingress__manager_to_device),
    .egress__device_to_manager(egress__device_to_manager),
    .ingress__device_to_manager(ingress__device_to_manager),
    .egress__manager_to_device(egress__manager_to_device)
  );

  initial begin
    ingress__manager_to_device = '{command: '{valid: 1'b1, bits: 8'hA5},
                                   enable: 1'b1,
                                   response: '{ready: 1'b1}};
    egress__device_to_manager = '{command: '{ready: 1'b1},
                                  response: '{valid: 1'b1, bits: 8'h5A},
                                  status: 8'h3C};
    #1;

    if (egress__manager_to_device.command.valid !== 1'b1 ||
        egress__manager_to_device.command.bits !== 8'hA5 ||
        egress__manager_to_device.enable !== 1'b1 ||
        egress__manager_to_device.response.ready !== 1'b1)
      $fatal(1, "nested forward interface flow failed");
    if (ingress__device_to_manager.command.ready !== 1'b1 ||
        ingress__device_to_manager.response.valid !== 1'b1 ||
        ingress__device_to_manager.response.bits !== 8'h5A ||
        ingress__device_to_manager.status !== 8'h3C)
      $fatal(1, "nested backward interface flow failed");

    $display("nested interface simulation passed");
    $finish;
  end
endmodule
