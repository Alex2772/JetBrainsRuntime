/*
 * Copyright (c) 2019, Oracle and/or its affiliates. All rights reserved.
 * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
 *
 * This code is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 2 only, as
 * published by the Free Software Foundation.  Oracle designates this
 * particular file as subject to the "Classpath" exception as provided
 * by Oracle in the LICENSE file that accompanied this code.
 *
 * This code is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * version 2 for more details (a copy is included in the LICENSE file that
 * accompanied this code).
 *
 * You should have received a copy of the GNU General Public License version
 * 2 along with this work; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 * Please contact Oracle, 500 Oracle Parkway, Redwood Shores, CA 94065 USA
 * or visit www.oracle.com if you need additional information or have any
 * questions.
 */

#ifndef HEADLESS

#include <jni.h>
#include <jlong.h>

#include "SurfaceData.h"
#include "MTLBlitLoops.h"
#include "MTLRenderQueue.h"
#include "MTLSurfaceData.h"
#include "MTLUtils.h"
#include "GraphicsPrimitiveMgr.h"

#include <stdlib.h> // malloc
#include <string.h> // memcpy
#include "IntArgbPre.h"

extern MTLPixelFormat PixelFormats[];
extern void J2dTraceImpl(int level, jboolean cr, const char *string, ...);

void fillTxQuad(
        struct TxtVertex * txQuadVerts,
        jint sx1, jint sy1, jint sx2, jint sy2, jint sw, jint sh,
        jdouble dx1, jdouble dy1, jdouble dx2, jdouble dy2, jdouble dw, jdouble dh
) {
    const float nsx1 = sx1/(float)sw;
    const float nsy1 = sy1/(float)sh;
    const float nsx2 = sx2/(float)sw;
    const float nsy2 = sy2/(float)sh;

    txQuadVerts[0].position[0] = dx1;
    txQuadVerts[0].position[1] = dy1;
    txQuadVerts[0].position[2] = 0;
    txQuadVerts[0].txtpos[0]   = nsx1;
    txQuadVerts[0].txtpos[1]   = nsy1;

    txQuadVerts[1].position[0] = dx2;
    txQuadVerts[1].position[1] = dy1;
    txQuadVerts[1].position[2] = 0;
    txQuadVerts[1].txtpos[0]   = nsx2;
    txQuadVerts[1].txtpos[1]   = nsy1;

    txQuadVerts[2].position[0] = dx2;
    txQuadVerts[2].position[1] = dy2;
    txQuadVerts[2].position[2] = 0;
    txQuadVerts[2].txtpos[0]   = nsx2;
    txQuadVerts[2].txtpos[1]   = nsy2;

    txQuadVerts[3].position[0] = dx2;
    txQuadVerts[3].position[1] = dy2;
    txQuadVerts[3].position[2] = 0;
    txQuadVerts[3].txtpos[0]   = nsx2;
    txQuadVerts[3].txtpos[1]   = nsy2;

    txQuadVerts[4].position[0] = dx1;
    txQuadVerts[4].position[1] = dy2;
    txQuadVerts[4].position[2] = 0;
    txQuadVerts[4].txtpos[0]   = nsx1;
    txQuadVerts[4].txtpos[1]   = nsy2;

    txQuadVerts[5].position[0] = dx1;
    txQuadVerts[5].position[1] = dy1;
    txQuadVerts[5].position[2] = 0;
    txQuadVerts[5].txtpos[0]   = nsx1;
    txQuadVerts[5].txtpos[1]   = nsy1;
}

/**
 * Inner loop used for copying a source MTL "Surface" (window, pbuffer,
 * etc.) to a destination OpenGL "Surface".  Note that the same surface can
 * be used as both the source and destination, as is the case in a copyArea()
 * operation.  This method is invoked from MTLBlitLoops_IsoBlit() as well as
 * MTLBlitLoops_CopyArea().
 *
 * The standard glCopyPixels() mechanism is used to copy the source region
 * into the destination region.  If the regions have different dimensions,
 * the source will be scaled into the destination as appropriate (only
 * nearest neighbor filtering will be applied for simple scale operations).
 */
static void
MTLBlitSurfaceToSurface(MTLContext *mtlc, BMTLSDOps *srcOps, BMTLSDOps *dstOps,
                        jint sx1, jint sy1, jint sx2, jint sy2,
                        jdouble dx1, jdouble dy1, jdouble dx2, jdouble dy2)
{
    //TODO
    J2dTraceNotImplPrimitive("MTLBlitSurfaceToSurface");
}

static void drawTex2Tex(MTLContext *mtlc,
                        id<MTLTexture> src, id<MTLTexture> dst,
                        jboolean rtt, jint hint,
                        jint sx1, jint sy1, jint sx2, jint sy2,
                        jdouble dx1, jdouble dy1, jdouble dx2, jdouble dy2)
{
    if (mtlc == NULL || src == nil || dst == nil)
        return;

//    J2dTraceLn2(J2D_TRACE_VERBOSE, "_drawTex2Tex: src tex=%p, dst tex=%p", src, dst);
//    J2dTraceLn4(J2D_TRACE_VERBOSE, "  sw=%d sh=%d dw=%d dh=%d", src.width, src.height, dst.width, dst.height);
//    J2dTraceLn4(J2D_TRACE_VERBOSE, "  sx1=%d sy1=%d sx2=%d sy2=%d", sx1, sy1, sx2, sy2);
//    J2dTraceLn4(J2D_TRACE_VERBOSE, "  dx1=%f dy1=%f dx2=%f dy2=%f", dx1, dy1, dx2, dy2);

    id<MTLRenderCommandEncoder> encoder = MTLContext_CreateSamplingEncoder(mtlc, dst);

    struct TxtVertex quadTxVerticesBuffer[6];
    fillTxQuad(quadTxVerticesBuffer, sx1, sy1, sx2, sy2, src.width, src.height, dx1, dy1, dx2, dy2, dst.width, dst.height);

    [encoder setVertexBytes:quadTxVerticesBuffer length:sizeof(quadTxVerticesBuffer) atIndex:MeshVertexBuffer];
    [encoder setFragmentTexture:src atIndex: 0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    [encoder endEncoding];
}

/**
 * Inner loop used for copying a source MTL "Texture" to a destination
 * MTL "Surface".  This method is invoked from MTLBlitLoops_IsoBlit().
 *
 * This method will copy, scale, or transform the source texture into the
 * destination depending on the transform state, as established in
 * and MTLContext_SetTransform().  If the source texture is
 * transformed in any way when rendered into the destination, the filtering
 * method applied is determined by the hint parameter (can be GL_NEAREST or
 * GL_LINEAR).
 */
static void
MTLBlitTextureToSurface(MTLContext *mtlc,
                        BMTLSDOps *srcOps, BMTLSDOps *dstOps,
                        jboolean rtt, jint hint,
                        jint sx1, jint sy1, jint sx2, jint sy2,
                        jdouble dx1, jdouble dy1, jdouble dx2, jdouble dy2)
{
    id<MTLTexture> srcTex = srcOps->pTexture;

#ifdef DEBUG
    J2dTraceImpl(J2D_TRACE_VERBOSE, JNI_TRUE, "MTLBlitLoops_IsoBlit [via sampling]: bsrc=%p [tex=%p], bdst=%p [tex=%p] | s (%dx%d) -> d (%dx%d) | src (%d, %d, %d, %d) -> dst (%1.2f, %1.2f, %1.2f, %1.2f)", srcOps, srcOps->pTexture, dstOps, dstOps->pTexture, srcTex.width, srcTex.height, dstOps->width, dstOps->height, sx1, sy1, sx2, sy2, dx1, dy1, dx2, dy2);
#endif //DEBUG

    drawTex2Tex(mtlc, srcOps->pTexture, dstOps->pTexture, rtt, hint, sx1, sy1, sx2, sy2, dx1, dy1, dx2, dy2);
}

/**
 * Inner loop used for copying a source system memory ("Sw") surface to a
 * destination MTL "Surface".  This method is invoked from
 * MTLBlitLoops_Blit().
 *
 * The standard glDrawPixels() mechanism is used to copy the source region
 * into the destination region.  If the regions have different
 * dimensions, the source will be scaled into the destination
 * as appropriate (only nearest neighbor filtering will be applied for simple
 * scale operations).
 */

static void
MTLBlitSwToSurfaceViaTexture(MTLContext *ctx, SurfaceDataRasInfo *srcInfo, BMTLSDOps * bmtlsdOps,
                   MTPixelFormat *pf,
                   jint sx1, jint sy1, jint sx2, jint sy2,
                   jdouble dx1, jdouble dy1, jdouble dx2, jdouble dy2)
{
    if (bmtlsdOps == NULL || bmtlsdOps->pTexture == NULL) {
        J2dTraceLn(J2D_TRACE_ERROR, "MTLBlitSwToSurfaceViaTexture: dest is null");
        return;
    }

    const int sw = sx2 - sx1;
    const int sh = sy2 - sy1;
    id<MTLTexture> dest = bmtlsdOps->pTexture;

#ifdef DEBUG
    J2dTraceImpl(J2D_TRACE_VERBOSE, JNI_TRUE, "MTLBlitLoops_Blit [via pooled texture]: bdst=%p [tex=%p], sw=%d, sh=%d | src (%d, %d, %d, %d) -> dst (%1.2f, %1.2f, %1.2f, %1.2f)", bmtlsdOps, dest, sw, sh, sx1, sy1, sx2, sy2, dx1, dy1, dx2, dy2);
#endif //DEBUG

    id<MTLTexture> texBuff = [ctx->mtlTexturePool getTexture:sw height:sh format:MTLPixelFormatBGRA8Unorm];
    if (texBuff == nil) {
        J2dTraceLn(J2D_TRACE_ERROR, "MTLBlitSwToSurfaceViaTexture: can't obtain temporary texture object from pool");
        return;
    }
    MTLRegion region = MTLRegionMake2D(0, 0, sw, sh);
    [texBuff replaceRegion:region mipmapLevel:0 withBytes:srcInfo->rasBase bytesPerRow:srcInfo->scanStride]; // texBuff is locked for current frame

    drawTex2Tex(ctx, texBuff, dest, 0, 0, 0, 0, sw, sh, dx1, dy1, dx2, dy2);
}

/**
 * Inner loop used for copying a source system memory ("Sw") surface or
 * MTL "Surface" to a destination OpenGL "Surface", using an MTL texture
 * tile as an intermediate surface.  This method is invoked from
 * MTLBlitLoops_Blit() for "Sw" surfaces and MTLBlitLoops_IsoBlit() for
 * "Surface" surfaces.
 *
 * This method is used to transform the source surface into the destination.
 * Pixel rectangles cannot be arbitrarily transformed (without the
 * GL_EXT_pixel_transform extension, which is not supported on most modern
 * hardware).  However, texture mapped quads do respect the GL_MODELVIEW
 * transform matrix, so we use textures here to perform the transform
 * operation.  This method uses a tile-based approach in which a small
 * subregion of the source surface is copied into a cached texture tile.  The
 * texture tile is then mapped into the appropriate location in the
 * destination surface.
 *
 * REMIND: this only works well using GL_NEAREST for the filtering mode
 *         (GL_LINEAR causes visible stitching problems between tiles,
 *         but this can be fixed by making use of texture borders)
 */
static void
MTLBlitToSurfaceViaTexture(MTLContext *mtlc, SurfaceDataRasInfo *srcInfo,
                           MTPixelFormat *pf, MTLSDOps *srcOps,
                           jboolean swsurface, jint hint,
                           jint sx1, jint sy1, jint sx2, jint sy2,
                           jdouble dx1, jdouble dy1, jdouble dx2, jdouble dy2)
{
    //TODO
    J2dTraceNotImplPrimitive("MTLBlitToSurfaceViaTexture");
}

/**
 * Inner loop used for copying a source system memory ("Sw") surface to a
 * destination OpenGL "Texture".  This method is invoked from
 * MTLBlitLoops_Blit().
 *
 * The source surface is effectively loaded into the MTL texture object,
 * which must have already been initialized by MTLSD_initTexture().  Note
 * that this method is only capable of copying the source surface into the
 * destination surface (i.e. no scaling or general transform is allowed).
 * This restriction should not be an issue as this method is only used
 * currently to cache a static system memory image into an MTL texture in
 * a hidden-acceleration situation.
 */
static void
MTLBlitSwToTexture(SurfaceDataRasInfo *srcInfo, MTPixelFormat *pf,
                   MTLSDOps *dstOps,
                   jint dx1, jint dy1, jint dx2, jint dy2)
{
    //TODO
    J2dTraceNotImplPrimitive("MTLBlitSwToTexture");
}

/**
 * General blit method for copying a native MTL surface (of type "Surface"
 * or "Texture") to another MTL "Surface".  If texture is JNI_TRUE, this
 * method will invoke the Texture->Surface inner loop; otherwise, one of the
 * Surface->Surface inner loops will be invoked, depending on the transform
 * state.
 *
 * REMIND: we can trick these blit methods into doing XOR simply by passing
 *         in the (pixel ^ xorpixel) as the pixel value and preceding the
 *         blit with a fillrect...
 */
void
MTLBlitLoops_IsoBlit(JNIEnv *env,
                     MTLContext *mtlc, jlong pSrcOps, jlong pDstOps,
                     jboolean xform, jint hint,
                     jboolean texture, jboolean rtt,
                     jint sx1, jint sy1, jint sx2, jint sy2,
                     jdouble dx1, jdouble dy1, jdouble dx2, jdouble dy2)
{
    BMTLSDOps *srcOps = (BMTLSDOps *)jlong_to_ptr(pSrcOps);
    BMTLSDOps *dstOps = (BMTLSDOps *)jlong_to_ptr(pDstOps);

    RETURN_IF_NULL(srcOps);
    RETURN_IF_NULL(dstOps);

    id<MTLTexture> srcTex = srcOps->pTexture;
    id<MTLTexture> dstTex = dstOps->pTexture;
    if (mtlc == NULL || srcTex == nil || srcTex == nil) {
        J2dTraceLn2(J2D_TRACE_ERROR, "MTLBlitLoops_IsoBlit: surface is null (stex=%p, dtex=%p)", srcTex, dstTex);
        return;
    }

    const jint sw    = sx2 - sx1;
    const jint sh    = sy2 - sy1;
    const jdouble dw = dx2 - dx1;
    const jdouble dh = dy2 - dy1;

    if (sw <= 0 || sh <= 0 || dw <= 0 || dh <= 0) {
        J2dTraceLn4(J2D_TRACE_WARNING, "MTLBlitLoops_IsoBlit: invalid dimensions: sw=%d, sh%d, dw=%d, dh=%d", sw, sh, dw, dh);
        return;
    }

    SurfaceDataRasInfo srcInfo;
    srcInfo.bounds.x1 = sx1;
    srcInfo.bounds.y1 = sy1;
    srcInfo.bounds.x2 = sx2;
    srcInfo.bounds.y2 = sy2;
    SurfaceData_IntersectBoundsXYXY(&srcInfo.bounds, 0, 0, srcOps->width, srcOps->height);

    if (srcInfo.bounds.x2 <= srcInfo.bounds.x1 || srcInfo.bounds.y2 <= srcInfo.bounds.y1) {
        J2dTraceLn(J2D_TRACE_VERBOSE, "MTLBlitLoops_IsoBlit: source rectangle doesn't intersect with source surface bounds");
        J2dTraceLn6(J2D_TRACE_VERBOSE, "  sx1=%d sy1=%d sx2=%d sy2=%d sw=%d sh=%d", sx1, sy1, sx2, sy2, srcOps->width, srcOps->height);
        J2dTraceLn4(J2D_TRACE_VERBOSE, "  dx1=%f dy1=%f dx2=%f dy2=%f", dx1, dy1, dx2, dy2);
        return;
    }

    if (srcInfo.bounds.x1 != sx1) {
        dx1 += (srcInfo.bounds.x1 - sx1) * (dw / sw);
        sx1 = srcInfo.bounds.x1;
    }
    if (srcInfo.bounds.y1 != sy1) {
        dy1 += (srcInfo.bounds.y1 - sy1) * (dh / sh);
        sy1 = srcInfo.bounds.y1;
    }
    if (srcInfo.bounds.x2 != sx2) {
        dx2 += (srcInfo.bounds.x2 - sx2) * (dw / sw);
        sx2 = srcInfo.bounds.x2;
    }
    if (srcInfo.bounds.y2 != sy2) {
        dy2 += (srcInfo.bounds.y2 - sy2) * (dh / sh);
        sy2 = srcInfo.bounds.y2;
    }

    const jboolean useBlitEncoder =
            MTLContext_IsBlendingDisabled(mtlc)
            && fabs(dx2 - dx1 - sx2 + sx1) < 0.001f && fabs(dy2 - dy1 - sy2 + sy1) < 0.001f // dimensions are equal (TODO: check that dx1,dy1 is integer)
            && !mtlc->useTransform; // TODO: check whether transform is simple translate (and use blitEncoder in this case)
    if (useBlitEncoder) {
#ifdef DEBUG
        J2dTraceImpl(J2D_TRACE_VERBOSE, JNI_TRUE, "MTLBlitLoops_IsoBlit [via blitEncoder]: bdst=%p [tex=%p] %dx%d | src (%d, %d, %d, %d) -> dst (%1.2f, %1.2f, %1.2f, %1.2f)", dstOps, dstTex, dstTex.width, dstTex.height, sx1, sy1, sx2, sy2, dx1, dy1, dx2, dy2);
#endif //DEBUG
        id <MTLBlitCommandEncoder> blitEncoder = MTLContext_CreateBlitEncoder(mtlc);
        [blitEncoder copyFromTexture:srcTex sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(sx1, sy1, 0) sourceSize:MTLSizeMake(sx2 - sx1, sy2 - sy1, 1) toTexture:dstTex destinationSlice:0 destinationLevel:0 destinationOrigin:MTLOriginMake(dx1, dy1, 0)];
        [blitEncoder endEncoding];
    } else {
        // TODO: support other flags
        MTLBlitTextureToSurface(mtlc, srcOps, dstOps, rtt, hint, sx1, sy1, sx2, sy2, dx1, dy1, dx2, dy2);
    }
}

/**
 * General blit method for copying a system memory ("Sw") surface to a native
 * MTL surface (of type "Surface" or "Texture").  If texture is JNI_TRUE,
 * this method will invoke the Sw->Texture inner loop; otherwise, one of the
 * Sw->Surface inner loops will be invoked, depending on the transform state.
 */
void
MTLBlitLoops_Blit(JNIEnv *env,
                  MTLContext *mtlc, jlong pSrcOps, jlong pDstOps,
                  jboolean xform, jint hint,
                  jint srctype, jboolean texture,
                  jint sx1, jint sy1, jint sx2, jint sy2,
                  jdouble dx1, jdouble dy1, jdouble dx2, jdouble dy2)
{
    RETURN_IF_NULL(jlong_to_ptr(pSrcOps));
    RETURN_IF_NULL(jlong_to_ptr(pDstOps));

    SurfaceDataOps *srcOps = (SurfaceDataOps *)jlong_to_ptr(pSrcOps);
    BMTLSDOps *dstOps = (BMTLSDOps *)jlong_to_ptr(pDstOps);
    SurfaceDataRasInfo srcInfo;
    MTLPixelFormat pf = MTLPixelFormatBGRA8Unorm;//PixelFormats[srctype];

    if (dstOps == NULL || dstOps->pTexture == NULL) {
        J2dTraceLn(J2D_TRACE_ERROR, "MTLBlitLoops_Blit: dest is null");
        return;
    }
    id<MTLTexture> dest = dstOps->pTexture;
    if (dx1 < 0) {
        sx1 += dx1;
        dx1 = 0;
    }
    if (dx2 > dest.width) {
        sx2 -= dx2 - dest.width;
        dx2 = dest.width;
    }
    if (dy1 < 0) {
        sy1 += dy1;
        dy1 = 0;
    }
    if (dy2 > dest.height) {
        sy2 -= dy2 - dest.height;
        dy2 = dest.height;
    }
    jint sw    = sx2 - sx1;
    jint sh    = sy2 - sy1;
    jdouble dw = dx2 - dx1;
    jdouble dh = dy2 - dy1;

    if (sw <= 0 || sh <= 0 || dw <= 0 || dh <= 0 || srctype < 0) {
        J2dTraceLn(J2D_TRACE_WARNING, "MTLBlitLoops_Blit: invalid dimensions or srctype");
        return;
    }

    srcInfo.bounds.x1 = sx1;
    srcInfo.bounds.y1 = sy1;
    srcInfo.bounds.x2 = sx2;
    srcInfo.bounds.y2 = sy2;

    if (srcOps->Lock(env, srcOps, &srcInfo, SD_LOCK_READ) != SD_SUCCESS) {
        J2dTraceLn(J2D_TRACE_WARNING, "MTLBlitLoops_Blit: could not acquire lock");
        return;
    }

    J2dTraceLn5(J2D_TRACE_VERBOSE, "MTLBlitLoops_Blit:  pf=%d texture=%d srctype=%d xform=%d hint=%d", pf, texture, srctype, xform, hint);

    if (srcInfo.bounds.x2 > srcInfo.bounds.x1 && srcInfo.bounds.y2 > srcInfo.bounds.y1) {
        srcOps->GetRasInfo(env, srcOps, &srcInfo);
        if (srcInfo.rasBase) {
            if (srcInfo.bounds.x1 != sx1) {
                dx1 += (srcInfo.bounds.x1 - sx1) * (dw / sw);
                sx1 = srcInfo.bounds.x1;
            }
            if (srcInfo.bounds.y1 != sy1) {
                dy1 += (srcInfo.bounds.y1 - sy1) * (dh / sh);
                sy1 = srcInfo.bounds.y1;
            }
            if (srcInfo.bounds.x2 != sx2) {
                dx2 += (srcInfo.bounds.x2 - sx2) * (dw / sw);
                sx2 = srcInfo.bounds.x2;
            }
            if (srcInfo.bounds.y2 != sy2) {
                dy2 += (srcInfo.bounds.y2 - sy2) * (dh / sh);
                sy2 = srcInfo.bounds.y2;
            }

            // NOTE: if (texture) => dest coordinates will always be integers since we only ever do a straight copy from sw to texture.
            const jboolean useReplaceRegion = texture ||
                    (MTLContext_IsBlendingDisabled(mtlc)
                    && fabs(dx2 - dx1 - sx2 + sx1) < 0.001f && fabs(dy2 - dy1 - sy2 + sy1) < 0.001f // dimensions are equal (TODO: check that dx1,dy1 is integer)
                    && !mtlc->useTransform); // TODO: check whether transform is simple translate (and use replaceRegion in this case)
            if (useReplaceRegion) {
                MTLRegion region = MTLRegionMake2D(dx1, dy1, dx2 - dx1, dy2 - dy1);
#ifdef DEBUG
                J2dTraceImpl(J2D_TRACE_VERBOSE, JNI_TRUE, "MTLBlitLoops_Blit [replaceRegion]: bdst=%p [tex=%p] %dx%d | src (%d, %d, %d, %d) -> dst (%1.2f, %1.2f, %1.2f, %1.2f)", dstOps, dest, dest.width, dest.height, sx1, sy1, sx2, sy2, dx1, dy1, dx2, dy2);
#endif //DEBUG
                [dest replaceRegion:region mipmapLevel:0 withBytes:srcInfo.rasBase bytesPerRow:srcInfo.scanStride]; // executed at CPU (sync), TODO: lock dest for current frame
            } else {
                MTLBlitSwToSurfaceViaTexture(mtlc, &srcInfo, dstOps, &pf, sx1, sy1, sx2, sy2, dx1, dy1, dx2, dy2);
            }
        }
        SurfaceData_InvokeRelease(env, srcOps, &srcInfo);
    }
    SurfaceData_InvokeUnlock(env, srcOps, &srcInfo);
}

/**
 * Specialized blit method for copying a native MTL "Surface" (pbuffer,
 * window, etc.) to a system memory ("Sw") surface.
 */
void
MTLBlitLoops_SurfaceToSwBlit(JNIEnv *env, MTLContext *mtlc,
                             jlong pSrcOps, jlong pDstOps, jint dsttype,
                             jint srcx, jint srcy, jint dstx, jint dsty,
                             jint width, jint height)
{
    //TODO
    J2dTraceNotImplPrimitive("MTLBlitLoops_SurfaceToSwBlit");
}

void
MTLBlitLoops_CopyArea(JNIEnv *env,
                      MTLContext *mtlc, BMTLSDOps *dstOps,
                      jint x, jint y, jint width, jint height,
                      jint dx, jint dy)
{
    //TODO
    J2dTraceNotImplPrimitive("MTLBlitLoops_CopyArea");
}

#endif /* !HEADLESS */
