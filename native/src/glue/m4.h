#pragma once
#include <cmath>
#include <algorithm>
#include <array>
/* tiny double-precision 4x4 / 3x3 helpers (row-major) for the glTF writers */
namespace na {
struct M4 { double m[4][4]; };
inline M4 m4id() { M4 r{}; for (int i = 0; i < 4; i++) r.m[i][i] = 1; return r; }
inline M4 mul(const M4 &a, const M4 &b)
{
	M4 r{};
	for (int i = 0; i < 4; i++) for (int j = 0; j < 4; j++) { double s = 0; for (int k = 0; k < 4; k++) s += a.m[i][k] * b.m[k][j]; r.m[i][j] = s; }
	return r;
}
/* inverse of an affine matrix (last row 0 0 0 1) */
inline bool inv3(const double a[3][3], double o[3][3])
{
	double c00 = a[1][1] * a[2][2] - a[1][2] * a[2][1], c01 = a[1][2] * a[2][0] - a[1][0] * a[2][2], c02 = a[1][0] * a[2][1] - a[1][1] * a[2][0];
	double det = a[0][0] * c00 + a[0][1] * c01 + a[0][2] * c02;
	if (std::fabs(det) < 1e-300) return false;
	double id = 1.0 / det;
	o[0][0] = c00 * id; o[0][1] = (a[0][2] * a[2][1] - a[0][1] * a[2][2]) * id; o[0][2] = (a[0][1] * a[1][2] - a[0][2] * a[1][1]) * id;
	o[1][0] = c01 * id; o[1][1] = (a[0][0] * a[2][2] - a[0][2] * a[2][0]) * id; o[1][2] = (a[0][2] * a[1][0] - a[0][0] * a[1][2]) * id;
	o[2][0] = c02 * id; o[2][1] = (a[0][1] * a[2][0] - a[0][0] * a[2][1]) * id; o[2][2] = (a[0][0] * a[1][1] - a[0][1] * a[1][0]) * id;
	return true;
}
inline double det3(const double a[3][3])
{
	return a[0][0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1]) - a[0][1] * (a[1][0] * a[2][2] - a[1][2] * a[2][0]) + a[0][2] * (a[1][0] * a[2][1] - a[1][1] * a[2][0]);
}
inline M4 inverse(const M4 &a)
{
	double l[3][3], li[3][3];
	for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) l[i][j] = a.m[i][j];
	M4 r = m4id();
	if (!inv3(l, li)) return r;
	for (int i = 0; i < 3; i++)
	{
		for (int j = 0; j < 3; j++) r.m[i][j] = li[i][j];
		r.m[i][3] = -(li[i][0] * a.m[0][3] + li[i][1] * a.m[1][3] + li[i][2] * a.m[2][3]);
	}
	return r;
}
inline M4 quat_mat(const double *q, const double ss[3][3])
{
	double n = std::sqrt(q[0] * q[0] + q[1] * q[1] + q[2] * q[2] + q[3] * q[3]);
	double x = q[0] / n, y = q[1] / n, z = q[2] / n, w = q[3] / n;
	double R[3][3] = { { 1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w) },
					   { 2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w) },
					   { 2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y) } };
	M4 r = m4id();
	for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) { double s = 0; for (int k = 0; k < 3; k++) s += R[i][k] * ss[k][j]; r.m[i][j] = s; }
	return r;
}
struct TRS { double t[3], q[4], s[3], err; };
/* affine -> translation, rotation (xyzw), scale (negative x scale for mirrored matrices); nearest-rotation by Newton iteration */
inline TRS decompose(const M4 &M)
{
	TRS o;
	for (int i = 0; i < 3; i++) o.t[i] = M.m[i][3];
	double A[3][3], R[3][3];
	for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) A[i][j] = M.m[i][j];
	double s[3];
	for (int j = 0; j < 3; j++) s[j] = std::sqrt(A[0][j] * A[0][j] + A[1][j] * A[1][j] + A[2][j] * A[2][j]);
	if (det3(A) < 0) s[0] = -s[0];
	for (int j = 0; j < 3; j++) if (std::fabs(s[j]) < 1e-12) s[j] = 1e-12;
	for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) R[i][j] = A[i][j] / s[j];
	double Q[3][3]; memcpy(Q, R, sizeof Q);
	for (int it = 0; it < 40; it++)
	{
		double Qi[3][3], N[3][3];
		if (!inv3(Q, Qi)) break;
		double d = 0;
		for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) { N[i][j] = 0.5 * (Q[i][j] + Qi[j][i]); d = std::max(d, std::fabs(N[i][j] - Q[i][j])); }
		memcpy(Q, N, sizeof Q);
		if (d < 1e-13) break;
	}
	if (det3(Q) < 0) for (int i = 0; i < 3; i++) Q[i][2] = -Q[i][2];
	double tr = Q[0][0] + Q[1][1] + Q[2][2], q[4];
	if (tr > 0) { double r = std::sqrt(1 + tr); double w = r / 2; r = 0.5 / r; q[0] = (Q[2][1] - Q[1][2]) * r; q[1] = (Q[0][2] - Q[2][0]) * r; q[2] = (Q[1][0] - Q[0][1]) * r; q[3] = w; }
	else
	{
		int i = 0; if (Q[1][1] > Q[i][i]) i = 1; if (Q[2][2] > Q[i][i]) i = 2;
		int j = (i + 1) % 3, k = (i + 2) % 3;
		double r = std::sqrt(Q[i][i] - Q[j][j] - Q[k][k] + 1);
		q[i] = r / 2; r = 0.5 / r;
		q[3] = (Q[k][j] - Q[j][k]) * r; q[j] = (Q[j][i] + Q[i][j]) * r; q[k] = (Q[k][i] + Q[i][k]) * r;
	}
	double n = std::sqrt(q[0] * q[0] + q[1] * q[1] + q[2] * q[2] + q[3] * q[3]);
	for (int i = 0; i < 4; i++) o.q[i] = q[i] / n;
	double e = 0;
	for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) e = std::max(e, std::fabs(Q[i][j] * s[j] - A[i][j]));
	for (int i = 0; i < 3; i++) o.s[i] = s[i];
	o.err = e;
	return o;
}
}  // namespace na
