package com.axis.rtspclient {

  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.external.ExternalInterface;
  import flash.utils.ByteArray;
  import flash.net.NetStream;

  import com.axis.rtspclient.RTP;

  public class FLVMux {
    private var jsEventCallbackName:String;
    private var container:ByteArray = new ByteArray();

    private var ns:NetStream;

    public function FLVMux(jsEventCallbackName:String)
    {
      ns = Player.getNetStream();
      this.jsEventCallbackName = jsEventCallbackName;

      container.writeByte(0x46); // 'F'
      container.writeByte(0x4C); // 'L'
      container.writeByte(0x56); // 'V'
      container.writeByte(0x01); // Version 1
      container.writeByte(0x00 << 2 | 0x01); // Audio << 2 | Video
      container.writeUnsignedInt(0x09) // Reserved: usually is 0x09
      container.writeUnsignedInt(0x0) // Previous tag size: shall be 0
    }

    public function createTag(nalu:NALU):void
    {
      var ts:uint = nalu.timestamp;
      var size:uint = 11; // Header to StreamID
      size += 1; // Video tag header
      size += 4; // AVC tag header
      size += nalu.bodySize;

      /* FLV Tag */
      container.writeUnsignedInt(0x09 << 24 | (size & 0x00FFFFFF)); // Type << 24 | size & 0x00FFFFFF
      container.writeUnsignedInt(ts >>> 24 | ts << 8);
      container.writeByte(0x00); container.writeByte(0x00); container.writeByte(0x00); // StreamID - always 0

      /* Video Tag Header */
      container.writeByte((nalu.isIDR ? 1 : 2) << 4 | 0x07); // Keyframe << 4 | CodecID
      container.writeUnsignedInt(0x01 << 24 | ts & 0x00FFFFFF); // AVC NALU << 24 | CompositionTime & 0x00FFFFFF

      /* Video Data */

      var n:ByteArray = nalu.getPayload();
      ExternalInterface.call(jsEventCallbackName, "pre - Nalu ba", n.bytesAvailable);
      ExternalInterface.call(jsEventCallbackName, "pre - container ba", container.bytesAvailable);
      ExternalInterface.call(jsEventCallbackName, "pre - Nalu len", n.length);
      ExternalInterface.call(jsEventCallbackName, "pre - container len", container.length);
      container.writeBytes(n, n.position);
      ExternalInterface.call(jsEventCallbackName, "post - Nalu ba", n.bytesAvailable);
      ExternalInterface.call(jsEventCallbackName, "post - container ba", container.bytesAvailable);
      ExternalInterface.call(jsEventCallbackName, "post - Nalu len", n.length);
      ExternalInterface.call(jsEventCallbackName, "post - container len", container.length);


      /* Previous Tag Size */
      container.writeUnsignedInt(size + 11);

      container.position = 0;
      ns.appendBytes(container);

      container.clear();
    }

    public function onNALU(nalu:NALU):void
    {
      createTag(nalu);
      ExternalInterface.call(jsEventCallbackName, "NALU received, idr: ", nalu.isIDR);
    }
  }
}
