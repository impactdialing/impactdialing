class PingController < ApplicationController
  def pong
    head :ok
  end
end