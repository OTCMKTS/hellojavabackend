module Datadog
  module Core
    module Buffer
      # Buffer that accumulates items for a consumer.
      # Consumption can happen from a different thread.

      # Buffer that stores objects. The buffer has a maximum size and when
      # the buffer is full, a random object is discarded.
      class Random
        def initialize(max_size)
          @max_size = max_size
          @items = []
          @closed = false
        end

        # Add a new ``item`` in the local queue. This method doesn't block the execution
        # even if the buffer is full.
        #
        # When the buffer is full, we try to ensure that we are fairly choosing newly
        # pushed items by randomly inserting them into the buffer slots. This discards
        # old items randomly while trying to ensure that recent items are still captured.
        def push(item)
          return if closed?

          full? ? replace!(item) : add!(item)
          item
        end

        # A bulk push alternative to +#push+. Use this method if
        # pushing more than one item for efficiency.
        def concat(items)
          return if closed?

          # Segment items into underflow and overflow
          underflow, overflow = overflow_segments(items)

          # Concatenate items do not exceed capacity.
          add_all!(underflow) unless underflow.nil?

          # Iteratively replace items, to ensure pseudo-random replacement.
          overflow.each { |item| replace!(item) } unless overflow.nil?
        end

        # Stored items are returned and the local buffer is reset.
        def pop
          drain!
        end

        # Return the current number of stored items.
        def length
          @items.length
        end

        # Return if the buffer is empty.
        def empty?
          @items.empty?
        end

        # Closes this buffer, preventing further pushing.
        # Draining is still allowed.
        def close
          @closed = true
  