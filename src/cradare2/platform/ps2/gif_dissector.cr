require "./registers"

module Cradare2
  module Platform
    module PS2
      class GifDissector
        PRIM_TYPES = {
          0 => "POINT",
          1 => "LINE",
          2 => "LINESTRIP",
          3 => "TRIANGLE",
          4 => "TRISTRIP",
          5 => "TRIFAN",
          6 => "SPRITE",
        }

        record GifTagInfo,
          nloop : UInt32,
          eop : Bool,
          flg : String,
          nreg : UInt32,
          raw_low : UInt64,
          raw_high : UInt64

        record GifItemInfo,
          index : Int32,
          offset : UInt32,
          reg_id : UInt64,
          reg_name : String,
          data : UInt64,
          description : String

        # Decodes a 128-bit GIFTag header from a 16-byte slice.
        def self.decode_giftag(slice : Bytes) : GifTagInfo
          return GifTagInfo.new(0_u32, false, "INVALID", 0_u32, 0_u64, 0_u64) if slice.size < 16

          low = IO::ByteFormat::LittleEndian.decode(UInt64, slice[0, 8])
          high = IO::ByteFormat::LittleEndian.decode(UInt64, slice[8, 8])

          nloop = (low & 0x7FFF).to_u32
          eop = ((low >> 15) & 1) == 1
          flg_val = (low >> 58) & 3
          flg_name = case flg_val
                     when 0 then "PACKED"
                     when 1 then "REGLIST"
                     when 2 then "IMAGE"
                     else        "DISABLE"
                     end
          nreg = ((low >> 60) & 0xF).to_u32

          GifTagInfo.new(nloop, eop, flg_name, nreg, low, high)
        end

        # Dissects a series of 128-bit GIF packet items.
        def self.dissect_packet(slice : Bytes, max_items : Int32 = 100) : Array(GifItemInfo)
          items = [] of GifItemInfo
          return items if slice.size < 16

          tag = decode_giftag(slice)
          pos = 16
          items_count = 0

          while items_count < tag.nloop && items_count < max_items && pos + 16 <= slice.size
            data = IO::ByteFormat::LittleEndian.decode(UInt64, slice[pos, 8])
            reg = IO::ByteFormat::LittleEndian.decode(UInt64, slice[pos + 8, 8])
            reg_id = reg & 0xFF
            reg_name = Registers::GS_REG_NAMES[reg_id]? || sprintf("REG_0x%02X", reg_id)
            desc = describe_gs_register(reg_id, data)

            items << GifItemInfo.new(items_count, pos.to_u32, reg_id, reg_name, data, desc)
            pos += 16
            items_count += 1
          end

          items
        end

        # Formats human-readable diagnostics for GS register payloads.
        def self.describe_gs_register(reg_id : UInt64, data : UInt64) : String
          case reg_id
          when Registers::REG_PRIM # PRIM
            ptype = (data & 7).to_i
            pname = PRIM_TYPES[ptype]? || "UNKNOWN(#{ptype})"
            iip = ((data >> 3) & 1) == 1 ? "Gouraud" : "Flat"
            tme = ((data >> 4) & 1) == 1 ? "TexOn" : "TexOff"
            abe = ((data >> 6) & 1) == 1 ? "BlendOn" : "BlendOff"
            ctxt = ((data >> 9) & 1) == 0 ? "Context1" : "Context2"
            "Type=#{pname}, Shading=#{iip}, #{tme}, #{abe}, #{ctxt} (raw=0x#{data.to_s(16)})"
          when Registers::REG_RGBAQ # RGBAQ
            r = (data & 0xFF).to_u8
            g = ((data >> 8) & 0xFF).to_u8
            b = ((data >> 16) & 0xFF).to_u8
            a = ((data >> 24) & 0xFF).to_u8
            q_raw = ((data >> 32) & 0xFFFFFFFF).to_u32
            q_float = IO::ByteFormat::LittleEndian.decode(Float32, Slice.new(pointerof(q_raw).as(UInt8*), 4)) rescue 1.0_f32
            "R=#{r}, G=#{g}, B=#{b}, A=#{a} (0x#{a.to_s(16)}), Q=#{q_float.round(2)}"
          when Registers::REG_XYZ2, Registers::REG_XYZ3 # XYZ2, XYZ3
            x_raw = (data & 0xFFFF).to_u16
            y_raw = ((data >> 16) & 0xFFFF).to_u16
            z_raw = ((data >> 32) & 0xFFFFFFFF).to_u32
            x_px = x_raw.to_f32 / 16.0_f32
            y_px = y_raw.to_f32 / 16.0_f32
            kick = reg_id == Registers::REG_XYZ2 ? "DRAW KICK" : "NO KICK"
            "X=#{x_px.round(1)}px (0x#{x_raw.to_s(16).rjust(4, '0')}), Y=#{y_px.round(1)}px (0x#{y_raw.to_s(16).rjust(4, '0')}), Z=0x#{z_raw.to_s(16)} [#{kick}]"
          when Registers::REG_XYOFFSET_1, Registers::REG_XYOFFSET_2 # XYOFFSET
            ofx_raw = (data & 0xFFFF).to_u16
            ofy_raw = ((data >> 32) & 0xFFFF).to_u16
            "OFX=#{ofx_raw.to_f32 / 16.0_f32}px, OFY=#{ofy_raw.to_f32 / 16.0_f32}px"
          when Registers::REG_SCISSOR_1, Registers::REG_SCISSOR_2 # SCISSOR
            x0 = data & 0x7FF
            x1 = (data >> 16) & 0x7FF
            y0 = (data >> 32) & 0x7FF
            y1 = (data >> 48) & 0x7FF
            "Bounds: (#{x0}, #{y0}) -> (#{x1}, #{y1})"
          when Registers::REG_TEST_1, Registers::REG_TEST_2 # TEST
            zte = (data >> 16) & 1
            ztst = (data >> 17) & 3
            ztst_name = case ztst
                        when 0 then "NEVER (All pixels fail!)"
                        when 1 then "ALWAYS (All pixels pass)"
                        when 2 then "GEQUAL (Z >= Zbuf)"
                        when 3 then "GREATER (Z > Zbuf)"
                        else        "UNKNOWN"
                        end
            ate = data & 1
            warn = (zte == 0 && ztst == 0) ? " [!! WARNING: ALWAYS DISCARD !!]" : ""
            "ZTE=#{zte}, ZTST=#{ztst} [#{ztst_name}], ATE=#{ate}#{warn}"
          when Registers::REG_FRAME_1, Registers::REG_FRAME_2 # FRAME
            fbp = data & 0x1FF
            fbw = (data >> 16) & 0x3F
            psm = (data >> 24) & 0x3F
            psm_name = psm == 0 ? "PSMCT32 (RGBA32)" : (psm == 1 ? "PSMCT24" : "PSM_#{psm}")
            "FBP=0x#{fbp.to_s(16)} (#{fbp * 2048} words), FBW=#{fbw} (#{fbw * 64}px), PSM=#{psm_name}"
          when Registers::REG_ZBUF_1, Registers::REG_ZBUF_2 # ZBUF
            zbp = data & 0x1FF
            psm = (data >> 24) & 0xF
            zmsk = (data >> 32) & 1
            "ZBP=0x#{zbp.to_s(16)}, PSM=#{psm}, ZMSK=#{zmsk == 1 ? "Masked(NoWrite)" : "Writable"}"
          when Registers::REG_PRMODECONT # PRMODECONT
            ac = data & 1
            "Source=#{ac == 1 ? "PRIM register" : "PRMODE register"}"
          when Registers::REG_COLCLAMP # COLCLAMP
            "Clamp=#{(data & 1) == 1 ? "Enabled" : "Disabled"}"
          else
            sprintf("RawData=0x%016X", data)
          end
        end
      end
    end
  end
end
